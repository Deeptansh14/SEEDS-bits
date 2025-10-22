# schemas.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class UserCreate(BaseModel):
    name: str
    phone_number: str
    password: str
    role: str  # 'teacher' or 'student'

class UserOut(BaseModel):
    user_id: int
    name: str
    phone_number: str
    role: str
    class Config:
        orm_mode = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[int] = None
    role: Optional[str] = None

class SessionCreate(BaseModel):
    title: str

class SessionOut(BaseModel):
    session_id: int
    title: Optional[str]
    is_active: bool
    created_by: Optional[int]
    class Config:
        orm_mode = True

class AudioCreateResponse(BaseModel):
    audio_id: int
    title: str
    file_path: str
    class Config:
        orm_mode = True

class PlaybackCreate(BaseModel):
    audio_id: int
