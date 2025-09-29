from django.urls import path
from . import views
from .views import LogoutView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path("health/", views.health),
    path("auth/register/", views.register),
    path("auth/token/", TokenObtainPairView.as_view()),
    path("auth/token/refresh/", TokenRefreshView.as_view()),
    path("api/logout/", LogoutView.as_view(), name="logout"),
    path("me/", views.MeView.as_view()),
    path("conversations/", views.ConversationView.as_view()),             # POST create, GET list
    path("conversations/<int:convo_id>/messages/", views.MessageView.as_view()),  # POST send, GET fetch
    path("messages/<int:msg_id>/view-once/", views.ViewOnceRead.as_view()),       # mark viewed
    path("profile/<str:username>/", views.get_profile_public_key),
   
]
