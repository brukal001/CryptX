# api/views.py
from django.contrib.auth.models import User
from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import models
from .models import Profile, Conversation, Message
from .serializers import (
    RegisterSerializer,
    ProfileSerializer,
    ConversationSerializer,
    MessageSerializer,
)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def health(_):
    return Response({"status": "ok"})


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def register(request):
    s = RegisterSerializer(data=request.data)
    if s.is_valid():
        s.save()
        return Response({"message": "registered"}, status=201)
    return Response(s.errors, status=400)


class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(ProfileSerializer(request.user.profile).data)

    def patch(self, request):
        s = ProfileSerializer(request.user.profile, data=request.data, partial=True)
        if s.is_valid():
            s.save()
            return Response(s.data)
        return Response(s.errors, status=400)


class ConversationView(APIView):
    def post(self, request):
        participants = request.data.get("participants", [])
        if not participants or not isinstance(participants, list):
            return Response({"error": "participants must be a list of usernames"}, status=400)

        # always include current user
        if request.user.username not in participants:
            participants.append(request.user.username)

        # find users
        users = User.objects.filter(username__in=participants)
        if users.count() != len(participants):
            return Response({"error": "invalid username(s) in participants"}, status=400)

        # check if a conversation with exactly this set exists
        existing = (
            Conversation.objects.filter(participants__in=users)
            .annotate(num_participants=models.Count("participants"))
            .filter(num_participants=len(participants))
        )

        for convo in existing:
            convo_participants = set(convo.participants.values_list("username", flat=True))
            if convo_participants == set(participants):
                # ✅ reuse existing convo
                return Response(ConversationSerializer(convo).data, status=200)

        # ✅ otherwise, create new convo
        convo = Conversation.objects.create()
        convo.participants.set(users)
        return Response(ConversationSerializer(convo).data, status=201)

    def get(self, request):
        qs = Conversation.objects.filter(participants=request.user).order_by("-created_at")
        return Response(ConversationSerializer(qs, many=True).data)




class MessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, convo_id):
        convo = get_object_or_404(Conversation, id=convo_id, participants=request.user)
        s = MessageSerializer(data=request.data)
        if s.is_valid():
            msg = Message.objects.create(
                conversation=convo,
                sender=request.user,
                ciphertext=s.validated_data["ciphertext"],
                nonce=s.validated_data["nonce"],
                tag=s.validated_data["tag"],
                view_once=s.validated_data.get("view_once", False),
            )
            return Response(MessageSerializer(msg).data, status=201)
        return Response(s.errors, status=400)

    def get(self, request, convo_id):
        convo = get_object_or_404(Conversation, id=convo_id, participants=request.user)
        msgs = convo.messages.order_by("created_at")
        return Response(MessageSerializer(msgs, many=True).data)


class ViewOnceRead(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, msg_id):
        msg = get_object_or_404(Message, id=msg_id)

        # Only the recipient (not the sender) can trigger the burn
        if request.user != msg.sender and request.user in msg.conversation.participants.all():
            if msg.view_once:
                msg.delete()   # 💣 delete permanently
                return Response({"deleted": True})

        return Response({"ok": True})



class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if not refresh_token:
                return Response({"error": "Refresh token required"}, status=400)

            token = RefreshToken(refresh_token)
            token.blacklist()  # requires blacklist app enabled
            return Response({"message": "Logged out successfully"}, status=205)
        except Exception as e:
            return Response(
                {"error": f"Invalid token: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def get_profile_public_key(request, username):
    user = get_object_or_404(User, username=username)
    return Response(
        {"username": username, "public_key": user.profile.public_key}
    )
