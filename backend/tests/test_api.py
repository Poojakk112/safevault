from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app import db
from app.auth import get_current_uid
from app.main import app


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(db, "DB_PATH", str(tmp_path / "test.db"))
    monkeypatch.setenv("CRON_KEY", "secret")
    sent_calls = []
    app.state.sender = lambda tokens, title: sent_calls.append((tokens, title)) or len(tokens)
    app.dependency_overrides[get_current_uid] = lambda: "user-1"
    c = TestClient(app)
    c.sent_calls = sent_calls
    yield c
    app.dependency_overrides.clear()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_requires_token_without_override():
    app.dependency_overrides.clear()
    res = TestClient(app).post("/devices", json={"token": "x" * 20, "platform": "android"})
    assert res.status_code == 401


def test_register_device_and_reminder_flow(client):
    assert client.post("/devices", json={"token": "fcm-token-123", "platform": "android"}).status_code == 204
    # Registering the same token again just updates it.
    assert client.post("/devices", json={"token": "fcm-token-123", "platform": "android"}).status_code == 204

    past = (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat()
    future = (datetime.now(timezone.utc) + timedelta(days=180)).isoformat()
    assert client.post("/reminders", json={"title": "Review vault", "remind_at": past}).status_code == 201
    assert client.post("/reminders", json={"title": "Later", "remind_at": future}).status_code == 201
    assert len(client.get("/reminders").json()) == 2

    res = client.post("/reminders/send-due", headers={"X-Cron-Key": "secret"})
    assert res.json() == {"due": 1, "notifications_sent": 1}
    assert client.sent_calls == [(["fcm-token-123"], "Review vault")]

    # Already sent reminders are not sent twice.
    res = client.post("/reminders/send-due", headers={"X-Cron-Key": "secret"})
    assert res.json() == {"due": 0, "notifications_sent": 0}


def test_send_due_requires_cron_key(client):
    assert client.post("/reminders/send-due").status_code == 403
    assert client.post("/reminders/send-due", headers={"X-Cron-Key": "wrong"}).status_code == 403


def test_validation(client):
    assert client.post("/devices", json={"token": "short", "platform": "android"}).status_code == 422
    assert client.post("/devices", json={"token": "x" * 20, "platform": "nokia"}).status_code == 422
    assert client.post("/reminders", json={"title": "", "remind_at": "2026-01-01T00:00:00Z"}).status_code == 422
