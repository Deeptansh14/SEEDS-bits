# ws_manager.py
from typing import Dict, List
from fastapi import WebSocket, WebSocketDisconnect
import asyncio

class ConnectionManager:
    def __init__(self):
        # session_id -> list of connected WebSockets
        self.active_connections: Dict[int, List[WebSocket]] = {}
        self.lock = asyncio.Lock()

    async def connect(self, session_id: int, websocket: WebSocket):
        await websocket.accept()
        async with self.lock:
            self.active_connections.setdefault(session_id, []).append(websocket)

    async def disconnect(self, session_id: int, websocket: WebSocket):
        async with self.lock:
            if session_id in self.active_connections:
                self.active_connections[session_id].remove(websocket)
                if not self.active_connections[session_id]:
                    self.active_connections.pop(session_id)

    async def broadcast(self, session_id: int, message: dict):
        if session_id not in self.active_connections:
            return
        dead = []
        for ws in self.active_connections[session_id]:
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(session_id, ws)

manager = ConnectionManager()
