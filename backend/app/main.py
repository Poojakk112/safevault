"""SafeVault backend (FastAPI).

Endpoints
- GET  /health                 health check
- POST /devices                save the phone's FCM token      (auth)
- POST /reminders              schedule a reminder push        (auth)
- GET  /reminders              list my reminders               (auth)
- POST /reminders/send-due     send due reminders via FCM      (X-Cron-Key)

Run locally:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

import os
from datetime import datetime, timezone
from typing import Callable

from fastapi import Depends, FastAPI, Header, HTTPException, status

from . import db
from .auth import get_current_uid, init_firebase
from .schemas import DeviceIn, ReminderIn, ReminderOut

app = FastAPI(title="SafeVault API", version="1.0.0")


def send_fcm(tokens: list[str], title: str) -> int:
    """Sends one push notification to each token. Returns how many succeeded."""
    from firebase_admin import messaging

    init_firebase()
    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title="SafeVault", body=title),
    )
    response = messaging.send_each_for_multicast(message)
    return response.success_count


# Tests replace this with a fake so no real notifications are sent.
app.state.sender: Callable[[list[str], str], int] = send_fcm


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/devices", status_code=status.HTTP_204_NO_CONTENT)
def register_device(body: DeviceIn, uid: str = Depends(get_current_uid)) -> None:
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO devices (token, uid, platform) VALUES (?, ?, ?) "
            "ON CONFLICT(token) DO UPDATE SET uid = excluded.uid, "
            "platform = excluded.platform, updated_at = datetime('now')",
            (body.token, uid, body.platform),
        )


@app.post("/reminders", status_code=status.HTTP_201_CREATED, response_model=ReminderOut)
def create_reminder(body: ReminderIn, uid: str = Depends(get_current_uid)) -> ReminderOut:
    remind_at = _to_utc(body.remind_at)
    with db.connect() as conn:
        cur = conn.execute(
            "INSERT INTO reminders (uid, title, remind_at) VALUES (?, ?, ?)",
            (uid, body.title, remind_at.isoformat()),
        )
        return ReminderOut(id=cur.lastrowid, title=body.title, remind_at=remind_at, sent=False)


@app.get("/reminders", response_model=list[ReminderOut])
def list_reminders(uid: str = Depends(get_current_uid)) -> list[ReminderOut]:
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT * FROM reminders WHERE uid = ? ORDER BY remind_at", (uid,)
        ).fetchall()
    return [
        ReminderOut(id=r["id"], title=r["title"], remind_at=r["remind_at"], sent=bool(r["sent"]))
        for r in rows
    ]


@app.post("/reminders/send-due")
def send_due_reminders(x_cron_key: str | None = Header(default=None)) -> dict:
    """Called by a scheduler (e.g. a cron job every hour).

    Protected by a shared secret in the CRON_KEY environment variable.
    """
    expected = os.getenv("CRON_KEY")
    if not expected or x_cron_key != expected:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Forbidden")

    now = datetime.now(timezone.utc).isoformat()
    sent = 0
    with db.connect() as conn:
        due = conn.execute(
            "SELECT * FROM reminders WHERE sent = 0 AND remind_at <= ?", (now,)
        ).fetchall()
        for reminder in due:
            tokens = [
                row["token"]
                for row in conn.execute(
                    "SELECT token FROM devices WHERE uid = ?", (reminder["uid"],)
                )
            ]
            if tokens:
                sent += app.state.sender(tokens, reminder["title"])
            conn.execute("UPDATE reminders SET sent = 1 WHERE id = ?", (reminder["id"],))
    return {"due": len(due), "notifications_sent": sent}


def _to_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
