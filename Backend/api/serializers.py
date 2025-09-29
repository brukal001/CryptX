from django.contrib.auth.models import User
from rest_framework import serializers
from .models import Profile, Conversation, Message

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    class Meta: model = User; fields = ["username","email","password"]
    def create(self, data):
        user = User.objects.create_user(username=data["username"], email=data["email"] ,password=data["password"])
        Profile.objects.create(user=user); return user

class ProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    class Meta: model = Profile; fields = ["username","public_key"]

class ConversationSerializer(serializers.ModelSerializer):
    peer = serializers.CharField(write_only=True)

    class Meta:
        model = Conversation
        fields = ["id", "participants", "created_at", "peer"]
        read_only_fields = ["id", "participants", "created_at"]

    def to_representation(self, instance):
        # Show participants as usernames
        rep = super().to_representation(instance)
        rep["participants"] = [u.username for u in instance.participants.all()]
        return rep



class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.SlugRelatedField(slug_field="username", read_only=True)
    class Meta: model = Message; fields = ["id","sender","ciphertext","nonce","tag","view_once","viewed","created_at"]
