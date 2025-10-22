import os
import aiofiles
import json
from datetime import datetime, timedelta

from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from . import models, schemas, auth
from .database import engine, get_db
from .ws_manager import manager   # NEW import

# Create FastAPI app
app = FastAPI(title="SEEDS Application")

# Allow CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Audio directory
AUDIO_DIR = os.getenv("AUDIO_DIR", "./data/audio")
os.makedirs(AUDIO_DIR, exist_ok=True)

# Create tables on startup
@app.on_event("startup")
async def startup_event():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)


# AUTHENTICATION :

@app.post("/auth/register", response_model=schemas.UserOut)
async def register(user_in: schemas.UserCreate, db: AsyncSession = Depends(get_db)):
    role = user_in.role.lower()
    if role not in ("teacher", "student"):
        raise HTTPException(status_code=400, detail="Invalid role")
    
    q = await db.execute(select(models.User).filter(models.User.phone_number == user_in.phone_number))
    existing = q.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Phone already registered")

    user = models.User(
        name=user_in.name,
        phone_number=user_in.phone_number,
        role=user_in.role,
        password_hash=auth.get_password_hash(user_in.password)
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@app.post("/auth/login", response_model=schemas.Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(),
                db: AsyncSession = Depends(get_db)):
    phone = form_data.username
    password = form_data.password

    q = await db.execute(select(models.User).filter(models.User.phone_number == phone))
    user = q.scalar_one_or_none()
    if not user or not auth.verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token_data = {"user_id": user.user_id, "role": user.role}
    access_token = auth.create_access_token(token_data, expires_delta=timedelta(days=7))
    return {"access_token": access_token, "token_type": "bearer"}


# SESSIONS :

@app.post("/sessions", response_model=schemas.SessionOut)
async def create_session(payload: schemas.SessionCreate,
                         user: models.User = Depends(auth.require_teacher),
                         db: AsyncSession = Depends(get_db)):
    s = models.Session(title=payload.title, created_by=user.user_id, is_active=True)
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return s


@app.post("/sessions/{session_id}/end")
async def end_session(session_id: int,
                      user: models.User = Depends(auth.require_teacher),
                      db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.Session).filter(models.Session.session_id == session_id))
    s = q.scalar_one_or_none()

    if not s:
        raise HTTPException(status_code=404, detail="Session not found")
    
    if s.created_by != user.user_id:
        raise HTTPException(status_code=403, detail="Only creator can end session")
    
    s.is_active = False
    s.ended_at = datetime.utcnow()
    await db.commit()
    # broadcast session-ended
    await manager.broadcast(session_id, {"type": "session-ended"})
    return {"ok": True}


# PARTICIPANTS :

@app.post("/sessions/{session_id}/participants")
async def add_participant(session_id: int, user_id: int,
                          db: AsyncSession = Depends(get_db),
                          current_user: models.User = Depends(auth.get_current_user)):
    q = await db.execute(select(models.Session).filter(models.Session.session_id == session_id))
    session = q.scalar_one_or_none()

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    if session.created_by != current_user.user_id:
        raise HTTPException(status_code=403, detail="You are not the creator of this session")

    q2 = await db.execute(select(models.Participant).filter(
        models.Participant.session_id == session_id,
        models.Participant.user_id == user_id
    ))
    exist = q2.scalar_one_or_none()
    if exist:
        return {"ok": True}

    p = models.Participant(session_id=session_id, user_id=user_id)
    db.add(p)
    await db.commit()
    await db.refresh(p)
    return {"ok": True, "participant_id": p.participant_id}


@app.delete("/sessions/{session_id}/participants/{participant_id}")
async def remove_participant(session_id: int, participant_id: int,
                             current_user: models.User = Depends(auth.require_teacher),
                             db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.Participant).filter(
        models.Participant.participant_id == participant_id,
        models.Participant.session_id == session_id
    ))
    p = q.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    p.is_kicked = True
    p.left_at = datetime.utcnow()
    await db.commit()
    await manager.broadcast(session_id, {
        "type": "participant-removed",
        "participant_id": participant_id,
        "user_id": p.user_id
    })
    return {"ok": True}


@app.post("/sessions/{session_id}/participants/{participant_id}/mute")
async def mute_participant(session_id: int, participant_id: int, mute: bool = True,
                           current_user: models.User = Depends(auth.require_teacher),
                           db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.Participant).filter(
        models.Participant.participant_id == participant_id,
        models.Participant.session_id == session_id
    ))
    p = q.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Participant not found")
    p.is_muted = mute
    await db.commit()
    await manager.broadcast(session_id, {
        "type": "participant-muted",
        "user_id": p.user_id,
        "muted": mute
    })
    return {"ok": True}


# AUDIO :

ALLOWED_EXTENSIONS = {".mp3", ".wav", ".m4a"}
ALLOWED_MIME_TYPES = {"audio/mpeg", "audio/wav", "audio/mp4"}

@app.post("/audio/upload", response_model=schemas.AudioCreateResponse)
async def upload_audio(title: str,
                       description: str = "",
                       file: UploadFile = File(...),
                       current_user: models.User = Depends(auth.require_teacher),
                       db: AsyncSession = Depends(get_db)):

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Invalid file extension {ext}")

    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid file type {file.content_type}")

    filename = f"{int(datetime.utcnow().timestamp())}_{file.filename}"
    file_path = os.path.join(AUDIO_DIR, filename)

    async with aiofiles.open(file_path, "wb") as out_file:
        content = await file.read()
        await out_file.write(content)

    af = models.AudioFile(
        title=title,
        description=description,
        file_path=file_path,
        uploaded_by=current_user.user_id
    )
    db.add(af)
    await db.commit()
    await db.refresh(af)
    return af


@app.get("/audio/{audio_id}/stream")
async def stream_audio(audio_id: int, db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.AudioFile).filter(models.AudioFile.audio_id == audio_id))
    af = q.scalar_one_or_none()
    if not af:
        raise HTTPException(status_code=404, detail="Audio not found")
    return FileResponse(path=af.file_path, filename=os.path.basename(af.file_path), media_type=af.mime_type)


@app.get("/audio/{audio_id}/play")
async def play_audio(audio_id: int, db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.AudioFile).filter(models.AudioFile.audio_id == audio_id))
    af = q.scalar_one_or_none()
    if not af:
        raise HTTPException(status_code=404, detail="Audio not found")

    def iterfile():
        with open(af.file_path, mode="rb") as file_like:
            yield from file_like

    return StreamingResponse(iterfile(), media_type=af.mime_type)


# WEBSOCKETS :

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: int, db: AsyncSession = Depends(get_db)):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return

    try:
        user = await auth.get_current_user_from_token(token, db)
    except Exception:
        await websocket.close(code=1008)
        return

    await manager.connect(session_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")
            if msg_type == "chat":
                await manager.broadcast(session_id, {
                    "type": "chat",
                    "from": user.user_id,
                    "text": data.get("text")
                })
            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        await manager.disconnect(session_id, websocket)

@app.get("/sessions/active")
async def list_active_sessions(db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(models.Session).filter(models.Session.is_active == True))
    sessions = q.scalars().all()
    return [{"id": s.session_id, "title": s.title} for s in sessions]
