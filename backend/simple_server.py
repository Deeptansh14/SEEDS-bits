from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from typing import Dict, List, Optional
import json
import asyncio

app = FastAPI(title="SEEDS WebSocket Test Server")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}
        self.user_info: Dict[WebSocket, Dict] = {}

    async def connect(self, websocket: WebSocket, session_id: int):
        await websocket.accept()
        if session_id not in self.active_connections:
            self.active_connections[session_id] = []
        self.active_connections[session_id].append(websocket)
        print(f"Client connected to session {session_id}. Total connections: {len(self.active_connections[session_id])}")

    def disconnect(self, websocket: WebSocket, session_id: int):
        if session_id in self.active_connections:
            if websocket in self.active_connections[session_id]:
                self.active_connections[session_id].remove(websocket)
            if len(self.active_connections[session_id]) == 0:
                del self.active_connections[session_id]
        
        # Remove user info
        if websocket in self.user_info:
            del self.user_info[websocket]
        
        print(f"Client disconnected from session {session_id}")

    async def send_personal_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: dict, session_id: int, exclude_websocket: Optional[WebSocket] = None):
        if session_id in self.active_connections:
            message_str = json.dumps(message)
            disconnected = []
            
            for connection in self.active_connections[session_id]:
                if connection != exclude_websocket:
                    try:
                        await connection.send_text(message_str)
                    except Exception as e:
                        print(f"Failed to send message: {e}")
                        disconnected.append(connection)
            
            # Clean up disconnected connections
            for conn in disconnected:
                if conn in self.active_connections[session_id]:
                    self.active_connections[session_id].remove(conn)
                if conn in self.user_info:
                    del self.user_info[conn]

manager = ConnectionManager()

@app.get("/")
async def root():
    return {"message": "SEEDS WebSocket Test Server is running!"}

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: int):
    await manager.connect(websocket, session_id)
    
    try:
        while True:
            # Receive message
            data = await websocket.receive_text()
            message = json.loads(data)
            
            print(f"Received message in session {session_id}: {message}")
            
            # Handle different message types
            message_type = message.get("type", "")
            user_name = message.get("user", "Unknown")
            
            if message_type == "user_info":
                # Store user information
                manager.user_info[websocket] = {
                    "name": message.get("name", "Unknown"),
                    "role": message.get("role", "student")
                }
                
                # Notify others about new participant
                await manager.broadcast({
                    "type": "participant_joined",
                    "user": user_name,
                    "message": f"{user_name} joined the session"
                }, session_id, exclude_websocket=websocket)
                
            elif message_type == "audio_chunk":
                # Broadcast audio chunk to all other participants (include mimeType for reliable playback)
                await manager.broadcast({
                    "type": "audio_chunk",
                    "data": message.get("data"),
                    "mimeType": message.get("mimeType", "audio/webm"),
                    "user": user_name
                }, session_id, exclude_websocket=websocket)
                
            elif message_type == "audio_file":
                # Broadcast complete audio file to all other participants
                await manager.broadcast({
                    "type": "audio_file",
                    "data": message.get("data"),
                    "filename": message.get("filename", ""),
                    "mimeType": message.get("mimeType", "audio/mp3"),
                    "user": user_name
                }, session_id, exclude_websocket=websocket)
                
            elif message_type == "audio_control":
                # Broadcast audio control messages
                await manager.broadcast({
                    "type": "audio_control",
                    "action": message.get("action"),
                    "message": message.get("message", ""),
                    "user": user_name
                }, session_id, exclude_websocket=websocket)
                
            elif message_type == "raise_hand":
                # Broadcast hand raise to all participants
                await manager.broadcast({
                    "type": "hand_raised",
                    "user": user_name,
                    "message": f"{user_name} raised their hand"
                }, session_id)
                
            elif message_type == "lower_hand":
                # Broadcast hand lower to all participants
                await manager.broadcast({
                    "type": "hand_lowered",
                    "user": user_name,
                    "message": f"{user_name} lowered their hand"
                }, session_id)
                
            elif message_type == "question":
                # Broadcast question to all participants
                await manager.broadcast({
                    "type": "question",
                    "user": user_name,
                    "question": message.get("question", ""),
                    "message": f"{user_name} asked a question"
                }, session_id)
                
            elif message_type == "chat":
                # Broadcast chat message to all participants
                await manager.broadcast({
                    "type": "chat",
                    "user": user_name,
                    "message": message.get("message", ""),
                    "timestamp": message.get("timestamp", "")
                }, session_id)
                
            elif message_type == "broadcast":
                # Teacher broadcasting to all students
                await manager.broadcast({
                    "type": "broadcast",
                    "user": user_name,
                    "message": message.get("message", "")
                }, session_id, exclude_websocket=websocket)
                
            elif message_type == "system_announcement":
                # System announcements
                await manager.broadcast({
                    "type": "system_announcement",
                    "user": user_name,
                    "message": message.get("message", "")
                }, session_id, exclude_websocket=websocket)
                
            else:
                # Echo back unknown message types
                await manager.send_personal_message(
                    json.dumps({
                        "type": "error", 
                        "message": f"Unknown message type: {message_type}"
                    }), 
                    websocket
                )
                
    except WebSocketDisconnect:
        user_info = manager.user_info.get(websocket, {})
        user_name = user_info.get("name", "Unknown")
        
        manager.disconnect(websocket, session_id)
        
        # Notify others about participant leaving
        await manager.broadcast({
            "type": "participant_left",
            "user": user_name,
            "message": f"{user_name} left the session"
        }, session_id)
        
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket, session_id)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)