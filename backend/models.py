# models.py
from sqlalchemy import (
    Column, Integer, String, Text, ForeignKey, Boolean,
    TIMESTAMP, CheckConstraint, JSON, text
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    name = Column(Text, nullable=False)
    phone_number = Column(Text, unique=True, nullable=False)
    role = Column(String(20), nullable=False)
    password_hash = Column(Text, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())

    __table_args__ = (
        CheckConstraint("role IN ('teacher', 'student')", name="check_role"),
    )

    sessions_created = relationship("Session", back_populates="creator")
    uploads = relationship("AudioFile", back_populates="uploader")


class Session(Base):
    __tablename__ = "sessions"

    session_id = Column(Integer, primary_key=True, index=True)
    title = Column(Text)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    is_active = Column(Boolean, server_default=text("true"))
    created_at = Column(TIMESTAMP, server_default=func.now())
    ended_at = Column(TIMESTAMP)

    creator = relationship("User", back_populates="sessions_created")
    participants = relationship("Participant", back_populates="session")
    playbacks = relationship("Playback", back_populates="session")
    questions = relationship("Question", back_populates="session")
    logs = relationship("Log", back_populates="session")


class Participant(Base):
    __tablename__ = "participants"

    participant_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.session_id", ondelete="CASCADE"))
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"))
    joined_at = Column(TIMESTAMP, server_default=func.now())
    left_at = Column(TIMESTAMP)
    is_muted = Column(Boolean, server_default=text("true"))
    is_kicked = Column(Boolean, server_default=text("false"))

    session = relationship("Session", back_populates="participants")
    user = relationship("User")

    __table_args__ = (
        CheckConstraint("user_id IS NOT NULL"),
    )


class AudioFile(Base):
    __tablename__ = "audio_files"

    audio_id = Column(Integer, primary_key=True, index=True)
    title = Column(Text, nullable=False)
    description = Column(Text)
    file_path = Column(Text, nullable=False)
    mime_type = Column(Text, server_default="audio/mpeg")
    uploaded_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    uploaded_at = Column(TIMESTAMP, server_default=func.now())

    uploader = relationship("User", back_populates="uploads")
    playbacks = relationship("Playback", back_populates="audio")


class Playback(Base):
    __tablename__ = "playback"

    playback_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.session_id", ondelete="CASCADE"))
    audio_id = Column(Integer, ForeignKey("audio_files.audio_id", ondelete="SET NULL"))
    started_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    started_at = Column(TIMESTAMP, server_default=func.now())
    ended_at = Column(TIMESTAMP)

    session = relationship("Session", back_populates="playbacks")
    audio = relationship("AudioFile", back_populates="playbacks")
    starter = relationship("User")


class Question(Base):
    __tablename__ = "questions"

    question_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.session_id", ondelete="CASCADE"))
    asked_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    content = Column(Text, nullable=False)
    asked_at = Column(TIMESTAMP, server_default=func.now())

    session = relationship("Session", back_populates="questions")
    asker = relationship("User")


class Log(Base):
    __tablename__ = "logs"

    log_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.session_id", ondelete="CASCADE"))
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    event_type = Column(String(50))
    event_details = Column(JSON)
    created_at = Column(TIMESTAMP, server_default=func.now())

    session = relationship("Session", back_populates="logs")
    user = relationship("User")


class JwtToken(Base):
    __tablename__ = "jwt_tokens"

    token_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"))
    token = Column(Text, unique=True, nullable=False)
    issued_at = Column(TIMESTAMP, server_default=func.now())
    expires_at = Column(TIMESTAMP)

    user = relationship("User")
