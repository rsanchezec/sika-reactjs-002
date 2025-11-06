"""
voice_websocket.py - WebSocket Server para Modo Voz

Endpoint WebSocket que integra VoiceManager con el frontend React
para proporcionar conversación por voz en tiempo real.
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict
import json
import uvicorn
import logging
import asyncio
from voice_manager import VoiceManager
import os
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SIKA AI Voice API")

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class VoiceConnectionManager:
    """
    Gestor de conexiones de voz WebSocket

    Coordina las sesiones de voz para cada usuario,
    manteniendo la coherencia con el agent_id usado en modo texto.
    """

    def __init__(self, agent_id: str):
        """
        Inicializa el gestor de conexiones de voz

        Args:
            agent_id: ID del agente de Azure AI (mismo que usa assistant_websocket.py)
        """
        self.agent_id = agent_id
        # Diccionario: user_id -> (websocket, voice_manager)
        self.active_sessions: Dict[str, tuple[WebSocket, VoiceManager]] = {}
        logger.info(f"VoiceConnectionManager initialized with agent_id: {agent_id}")

    async def start_session(self, websocket: WebSocket, user_id: str) -> str:
        """
        Inicia una sesión de voz para un usuario

        Args:
            websocket: Conexión WebSocket del cliente
            user_id: Identificador del usuario

        Returns:
            session_id: ID de la sesión de voz creada
        """
        try:
            # Obtener el event loop actual para pasarlo al VoiceManager
            loop = asyncio.get_event_loop()

            # Crear VoiceManager con el mismo agent_id que usa el modo texto
            # enable_local_audio=False porque el servidor no necesita reproducir audio localmente
            voice_manager = VoiceManager(agent_id=self.agent_id, event_loop=loop, enable_local_audio=False)

            # Configurar callbacks para enviar eventos al frontend
            # Usar funciones async directamente sin create_task
            async def send_session_created(session_id):
                await self._send_event(websocket, "voice_session_ready", {"session_id": session_id})

            async def send_user_transcript(transcript):
                await self._send_event(websocket, "user_transcript", {"text": transcript})

            async def send_agent_text(text):
                await self._send_event(websocket, "agent_text", {"text": text})

            async def send_agent_transcript(transcript):
                await self._send_event(websocket, "agent_transcript", {"text": transcript})

            async def send_agent_audio(audio_bytes):
                # Enviar audio binario al cliente
                logger.debug(f"Enviando audio al cliente: {len(audio_bytes)} bytes")
                await websocket.send_bytes(audio_bytes)

            async def send_user_speech_started():
                # ✅ NUEVO: Notificar al frontend que el usuario empezó a hablar
                logger.info(f"Notificando al frontend que el usuario interrumpió")
                await self._send_event(websocket, "input_audio_buffer.speech_started", {})

            voice_manager.on_session_created = send_session_created
            voice_manager.on_user_transcript = send_user_transcript
            voice_manager.on_agent_response = send_agent_text
            voice_manager.on_agent_audio_transcript = send_agent_transcript
            voice_manager.on_agent_audio = send_agent_audio
            voice_manager.on_user_speech_started = send_user_speech_started  # ✅ NUEVO

            # Iniciar sesión de voz
            session_id = voice_manager.start()

            # Guardar sesión activa
            self.active_sessions[user_id] = (websocket, voice_manager)

            logger.info(f"Voice session started for user {user_id}")
            return session_id

        except Exception as e:
            logger.error(f"Error starting voice session: {e}")
            raise

    async def _send_event(self, websocket: WebSocket, event_type: str, data: dict):
        """
        Envía un evento al cliente a través del WebSocket

        Args:
            websocket: Conexión WebSocket
            event_type: Tipo de evento
            data: Datos del evento
        """
        try:
            message = {
                "type": event_type,
                **data
            }
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Error sending event: {e}")

    def send_audio(self, user_id: str, audio_data: bytes):
        """
        Envía datos de audio al VoiceManager del usuario

        Args:
            user_id: ID del usuario
            audio_data: Bytes de audio PCM
        """
        if user_id not in self.active_sessions:
            logger.warning(f"No active voice session for user {user_id}")
            return

        _, voice_manager = self.active_sessions[user_id]
        try:
            voice_manager.send_audio(audio_data)
        except Exception as e:
            logger.error(f"Error sending audio: {e}")

    def cancel_response(self, user_id: str):
        """
        Cancela la respuesta actual del agente para un usuario

        Args:
            user_id: ID del usuario
        """
        if user_id not in self.active_sessions:
            logger.warning(f"No active voice session for user {user_id}")
            return

        _, voice_manager = self.active_sessions[user_id]
        try:
            voice_manager.cancel_response()
            logger.info(f"Response cancelled for user {user_id}")
        except Exception as e:
            logger.error(f"Error cancelling response: {e}")

    def stop_session(self, user_id: str):
        """
        Detiene la sesión de voz de un usuario

        Args:
            user_id: ID del usuario
        """
        if user_id in self.active_sessions:
            _, voice_manager = self.active_sessions[user_id]
            voice_manager.stop()
            del self.active_sessions[user_id]
            logger.info(f"Voice session stopped for user {user_id}")

    def get_stats(self) -> dict:
        """Obtiene estadísticas de sesiones activas"""
        return {
            "agent_id": self.agent_id,
            "active_voice_sessions": len(self.active_sessions),
            "users": list(self.active_sessions.keys())
        }


# Crear instancia global del gestor
# Usa el mismo AZURE_AGENT_ID que assistant_websocket.py
AGENT_ID = os.getenv("AZURE_AGENT_ID")
if not AGENT_ID:
    logger.error("AZURE_AGENT_ID not found in environment variables!")
    raise ValueError("AZURE_AGENT_ID is required")

voice_manager = VoiceConnectionManager(agent_id=AGENT_ID)


@app.get("/")
async def root():
    """Endpoint de información"""
    return {
        "message": "SIKA AI Voice API",
        "status": "online",
        "agent_id": AGENT_ID,
        "active_sessions": len(voice_manager.active_sessions)
    }


@app.get("/health")
async def health():
    """Health check con estadísticas"""
    stats = voice_manager.get_stats()
    return {
        "status": "healthy",
        "stats": stats
    }


@app.websocket("/ws/voice")
async def websocket_voice_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint para conversación por voz

    PROTOCOLO DE COMUNICACIÓN:

    1. Cliente se conecta e inicializa sesión de voz:
    {
        "type": "init_voice",
        "user_id": "usuario_123"
    }

    Respuesta:
    {
        "type": "voice_session_ready",
        "session_id": "session_abc123"
    }

    2. Cliente envía audio (datos binarios):
    - Envía bytes directamente (PCM 16-bit, mono, 24kHz)

    3. Servidor envía eventos (JSON):
    {
        "type": "user_transcript",
        "text": "transcripción de lo que dijo el usuario"
    }

    {
        "type": "agent_text",
        "text": "respuesta del agente"
    }

    {
        "type": "agent_transcript",
        "text": "transcripción del audio del agente"
    }

    4. Servidor envía audio del agente (datos binarios):
    - Envía bytes directamente (PCM 16-bit, mono, 24kHz)
    - El cliente debe reproducir este audio

    5. Cliente detiene sesión de voz:
    {
        "type": "stop_voice"
    }
    """

    current_user_id = None

    try:
        # Aceptar conexión WebSocket
        await websocket.accept()
        logger.info("Voice WebSocket connection accepted")

        # Esperar mensaje de inicialización
        init_data = await websocket.receive_json()

        if init_data.get("type") != "init_voice":
            await websocket.send_json({
                "type": "error",
                "message": "Expected 'init_voice' message first"
            })
            await websocket.close()
            return

        user_id = init_data.get("user_id", "anonymous_user")
        current_user_id = user_id

        # Iniciar sesión de voz
        try:
            session_id = await voice_manager.start_session(websocket, user_id)
            logger.info(f"Voice session {session_id} started for user {user_id}")
        except Exception as e:
            await websocket.send_json({
                "type": "error",
                "message": f"Failed to start voice session: {str(e)}"
            })
            await websocket.close()
            return

        # Loop principal de mensajes
        while True:
            # Recibir mensaje (puede ser JSON o bytes de audio)
            try:
                message = await websocket.receive()

                # Si es texto JSON (comandos)
                if "text" in message:
                    data = json.loads(message["text"])
                    message_type = data.get("type")

                    if message_type == "stop_voice":
                        logger.info(f"Stopping voice session for {user_id}")
                        voice_manager.stop_session(user_id)
                        await websocket.send_json({
                            "type": "voice_session_stopped"
                        })
                        break

                    elif message_type == "response.cancel":
                        # ✅ NUEVO: Cancelar la respuesta actual del agente
                        logger.info(f"🛑 User {user_id} interrupted agent - cancelling response")
                        voice_manager.cancel_response(user_id)
                        # No necesitamos enviar respuesta al frontend, el audio simplemente se detendrá

                # Si es datos binarios (audio)
                elif "bytes" in message:
                    audio_data = message["bytes"]
                    # Enviar audio al VoiceManager
                    voice_manager.send_audio(user_id, audio_data)

            except json.JSONDecodeError:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON format"
                })

    except WebSocketDisconnect:
        logger.info(f"Voice client disconnected: {current_user_id}")
        if current_user_id:
            voice_manager.stop_session(current_user_id)

    except Exception as e:
        logger.error(f"Error in voice WebSocket: {e}")
        if current_user_id:
            voice_manager.stop_session(current_user_id)


if __name__ == "__main__":
    print("\n" + "="*60)
    print("🎤 SIKA AI Voice Assistant API")
    print("="*60)
    print("📍 URL: http://localhost:8001")
    print("🔌 WebSocket: ws://localhost:8001/ws/voice")
    print("📊 Health: http://localhost:8001/health")
    print("="*60)
    print(f"🤖 Agent ID: {AGENT_ID}")
    print("🎙️ Voice Live API enabled")
    print("="*60 + "\n")

    uvicorn.run(
        "voice_websocket:app",
        host="0.0.0.0",
        port=8001,  # Puerto diferente al de texto (8000)
        reload=True
    )
