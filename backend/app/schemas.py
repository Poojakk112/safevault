from datetime import datetime

from pydantic import BaseModel, Field


class DeviceIn(BaseModel):
    token: str = Field(min_length=10)
    platform: str = Field(pattern="^(android|ios|web)$")


class ReminderIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    remind_at: datetime


class ReminderOut(BaseModel):
    id: int
    title: str
    remind_at: datetime
    sent: bool
