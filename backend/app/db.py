"""Tiny SQLite storage for device tokens and reminders."""

import os
import sqlite3
from contextlib import contextmanager

DB_PATH = os.getenv("DB_PATH", "safevault.db")

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    token      TEXT PRIMARY KEY,
    uid        TEXT NOT NULL,
    platform   TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS reminders (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    uid       TEXT NOT NULL,
    title     TEXT NOT NULL,
    remind_at TEXT NOT NULL,
    sent      INTEGER NOT NULL DEFAULT 0
);
"""


@contextmanager
def connect(path: str | None = None):
    conn = sqlite3.connect(path or DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        conn.executescript(SCHEMA)
        yield conn
        conn.commit()
    finally:
        conn.close()
