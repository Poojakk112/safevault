"""Verifies the Firebase ID token (JWT) sent by the Flutter app.

The app sends:  Authorization: Bearer <firebase-id-token>
We verify it with the Firebase Admin SDK and get the user's uid.
"""

import os

import firebase_admin
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

_bearer = HTTPBearer(auto_error=False)


def init_firebase() -> None:
    """Initialise Firebase Admin once.

    Uses the service-account JSON file path in GOOGLE_APPLICATION_CREDENTIALS.
    """
    if firebase_admin._apps:  # already initialised
        return
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if cred_path:
        firebase_admin.initialize_app(credentials.Certificate(cred_path))
    else:
        firebase_admin.initialize_app()


def get_current_uid(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """FastAPI dependency: returns the uid of the calling user or 401."""
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    try:
        init_firebase()
        decoded = firebase_auth.verify_id_token(creds.credentials)
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return decoded["uid"]
