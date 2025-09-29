from django.conf import settings
from django.db import models

class Profile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="profile")
    display_name = models.CharField(max_length=120, blank=True)
    public_key = models.TextField(blank=True)  # base64 X25519 public key
    def __str__(self): return self.display_name or self.user.username

class Conversation(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name="conversations")

class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    ciphertext = models.TextField()   # NEVER store plaintext
    nonce = models.CharField(max_length=48)
    tag = models.CharField(max_length=48)
    view_once = models.BooleanField(default=False)
    viewed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    