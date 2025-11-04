"""
voice_manager.py - Gestor de Audio para Azure Voice Live API

Extrae la lógica de audio de agent_hub.py en una clase reutilizable
para integrarla con el sistema WebSocket del chatbot.
"""

import os
import uuid
import json
import base64
import logging
import threading
import numpy as np
import sounddevice as sd
import queue
import time
import asyncio
from collections import deque
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
import websocket
from websocket import WebSocketApp
from typing import Optional, Callable
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

logger = logging.getLogger(__name__)
AUDIO_SAMPLE_RATE = 24000  # 24 kHz


def get_azure_credential():
    logger.info("🔑 Using DefaultAzureCredential (env → managed identity → cli)")
    return DefaultAzureCredential(exclude_interactive_browser_credential=True)

# ===== CLASE DE CONEXIÓN WEBSOCKET =====
class VoiceLiveConnection:
    """Clase que maneja la conexión WebSocket con el servicio Azure Voice Live"""

    def __init__(self, url: str, headers: dict) -> None:
        """Inicializa la conexión con URL y headers"""
        self._url = url
        self._headers = headers
        self._ws = None
        self._message_queue = queue.Queue()
        self._connected = False

    def connect(self) -> None:
        """Establece la conexión WebSocket con el servidor"""

        def on_message(ws, message):
            """Callback ejecutado cuando se recibe un mensaje del servidor"""
            self._message_queue.put(message)

        def on_error(ws, error):
            """Callback ejecutado cuando ocurre un error en el WebSocket"""
            logger.error(f"WebSocket error: {error}")

        def on_close(ws, close_status_code, close_msg):
            """Callback ejecutado cuando el WebSocket se cierra"""
            logger.info("WebSocket connection closed")
            self._connected = False

        def on_open(ws):
            """Callback ejecutado cuando el WebSocket se abre exitosamente"""
            logger.info("WebSocket connection opened")
            self._connected = True

        self._ws = websocket.WebSocketApp(
            self._url,
            header=self._headers,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
            on_open=on_open
        )

        # Start WebSocket in a separate thread
        self._ws_thread = threading.Thread(target=self._ws.run_forever)
        self._ws_thread.daemon = True
        self._ws_thread.start()

        # Wait for connection to be established
        timeout = 10
        start_time = time.time()
        while not self._connected and time.time() - start_time < timeout:
            time.sleep(0.1)

        if not self._connected:
            raise ConnectionError("Failed to establish WebSocket connection")

    def recv(self) -> Optional[str]:
        """Recibe un mensaje de la cola de mensajes"""
        try:
            return self._message_queue.get(timeout=1)
        except queue.Empty:
            return None

    def send(self, message: str) -> None:
        """Envía un mensaje al servidor a través del WebSocket"""
        if self._ws and self._connected:
            self._ws.send(message)

    def close(self) -> None:
        """Cierra la conexión WebSocket"""
        if self._ws:
            self._ws.close()
            self._connected = False


# ===== CLASE CLIENTE DE AZURE VOICE LIVE =====
class AzureVoiceLive:
    """Cliente principal para interactuar con el servicio Azure Voice Live"""

    def __init__(
        self,
        *,
        azure_endpoint: str | None = None,
        api_version: str | None = None,
        token: str | None = None,
        api_key: str | None = None,
    ) -> None:
        """Inicializa el cliente con las credenciales y configuración necesarias"""
        self._azure_endpoint = azure_endpoint
        self._api_version = api_version
        self._token = token
        self._api_key = api_key
        self._connection = None

    def connect(self, agent_connection_string: str, agent_id: str, agent_access_token: str) -> VoiceLiveConnection:
        """Establece una conexión con Voice Live usando connection string del agente"""

        if self._connection is not None:
            raise ValueError("Already connected to the Voice Live API.")
        if not agent_connection_string:
            raise ValueError("Agent connection string is required.")
        if not agent_id:
            raise ValueError("Agent ID is required.")
        if not agent_access_token:
            raise ValueError("Agent access token is required.")

        # Construir URL del WebSocket
        azure_ws_endpoint = self._azure_endpoint.rstrip('/').replace("https://", "wss://")
        url = f"{azure_ws_endpoint}/voice-live/realtime?api-version={self._api_version}&agent-connection-string={agent_connection_string}&agent-id={agent_id}&agent-access-token={agent_access_token}"

        # Construir headers de autenticación
        auth_header = {"Authorization": f"Bearer {self._token}"} if self._token else {"api-key": self._api_key}
        request_id = uuid.uuid4()
        headers = {"x-ms-client-request-id": str(request_id), **auth_header}

        # Crear y conectar
        self._connection = VoiceLiveConnection(url, headers)
        self._connection.connect()
        return self._connection


# ===== CLASE DE REPRODUCTOR DE AUDIO ASÍNCRONO =====
class AudioPlayerAsync:
    """Clase que reproduce audio de manera asíncrona usando un buffer en cola"""

    def __init__(self):
        """Inicializa el reproductor con su buffer, stream y estado"""
        self.queue = deque()
        self.lock = threading.Lock()
        self.stream = sd.OutputStream(
            callback=self.callback,
            samplerate=AUDIO_SAMPLE_RATE,
            channels=1,
            dtype=np.int16,
            blocksize=2400,
        )
        self.playing = False

    def callback(self, outdata, frames, time, status):
        """Callback llamado por el stream de audio cuando necesita datos para reproducir"""
        if status:
            logger.warning(f"Stream status: {status}")

        with self.lock:
            data = np.empty(0, dtype=np.int16)

            while len(data) < frames and len(self.queue) > 0:
                item = self.queue.popleft()
                frames_needed = frames - len(data)
                data = np.concatenate((data, item[:frames_needed]))
                if len(item) > frames_needed:
                    self.queue.appendleft(item[frames_needed:])

            if len(data) < frames:
                data = np.concatenate((data, np.zeros(frames - len(data), dtype=np.int16)))

        outdata[:] = data.reshape(-1, 1)

    def add_data(self, data: bytes):
        """Agrega datos de audio al buffer de reproducción"""
        with self.lock:
            np_data = np.frombuffer(data, dtype=np.int16)
            self.queue.append(np_data)
            if not self.playing and len(self.queue) > 0:
                self.start()

    def start(self):
        """Inicia la reproducción de audio"""
        if not self.playing:
            self.playing = True
            self.stream.start()

    def stop(self):
        """Detiene la reproducción y limpia el buffer"""
        with self.lock:
            self.queue.clear()
        self.playing = False
        self.stream.stop()

    def terminate(self):
        """Termina completamente el reproductor y libera recursos"""
        with self.lock:
            self.queue.clear()
        self.stream.stop()
        self.stream.close()


# ===== GESTOR DE VOZ PRINCIPAL =====
class VoiceManager:
    """
    Gestor principal de voz que coordina la conexión con Azure Voice Live,
    captura de audio del micrófono y reproducción de respuestas.
    """

    def __init__(self, agent_id: str, event_loop=None, enable_local_audio=False):
        """
        Inicializa el VoiceManager con el ID del agente

        Args:
            agent_id: ID del agente de Azure AI (debe ser el mismo que usa ProductionAssistant)
            event_loop: Event loop de asyncio para ejecutar callbacks asíncronos
            enable_local_audio: Si True, reproduce audio localmente (para testing). Si False, solo envía audio via callbacks (para servidor)
        """
        self.agent_id = agent_id
        self.connection = None
        self.audio_player = None
        self.enable_local_audio = enable_local_audio
        self.stop_event = threading.Event()
        self.is_running = False
        self.event_loop = event_loop  # Store the event loop for async callbacks

        # Callbacks para eventos
        self.on_user_transcript: Optional[Callable[[str], None]] = None
        self.on_agent_response: Optional[Callable[[str], None]] = None
        self.on_agent_audio_transcript: Optional[Callable[[str], None]] = None
        self.on_session_created: Optional[Callable[[str], None]] = None
        self.on_agent_audio: Optional[Callable[[bytes], None]] = None  # Callback para enviar audio al cliente

    def start(self) -> str:
        """
        Inicia la sesión de voz con Azure Voice Live

        Returns:
            session_id: ID de la sesión creada
        """
        if self.is_running:
            raise ValueError("Voice session already running")

        # Configuración desde variables de entorno
        endpoint = os.environ.get("AZURE_VOICELIVE_ENDPOINT")
        agent_connection_string = os.environ.get("AI_FOUNDRY_AGENT_CONNECTION_STRING")
        api_version = os.environ.get("AZURE_VOICELIVE_API_VERSION", "2025-10-01")

        # Verificar credenciales de Service Principal
        tenant_id = os.environ.get("AZURE_TENANT_ID")
        client_id = os.environ.get("AZURE_CLIENT_ID")
        client_secret = os.environ.get("AZURE_CLIENT_SECRET")

        logger.info(f"Endpoint: {endpoint}")
        logger.info(f"Agent Connection String: {agent_connection_string[:20]}..." if agent_connection_string else "None")
        logger.info(f"API Version: {api_version}")
        logger.info(f"Tenant ID: {'***' + tenant_id[-4:] if tenant_id else 'None'}")
        logger.info(f"Client ID: {'***' + client_id[-4:] if client_id else 'None'}")
        logger.info(f"Client Secret: {'***' if client_secret else 'None'}")

        if not endpoint or not agent_connection_string:
            raise ValueError("Azure Voice Live configuration missing in .env")

        if not tenant_id or not client_id or not client_secret:
            logger.warning("Service Principal credentials not found. Will try other authentication methods.")

        # Autenticación (usa Managed Identity en Azure, Service Principal en local)
        credential = get_azure_credential()

        # Token para Voice Live API
        token = credential.get_token("https://ai.azure.com/.default")

        # Token para el agente
        agent_token = credential.get_token("https://ml.azure.com/.default")

        # Crear cliente y conectar
        client = AzureVoiceLive(
            azure_endpoint=endpoint,
            api_version=api_version,
            token=token.token,
        )

        self.connection = client.connect(
            agent_connection_string=agent_connection_string,
            agent_id=self.agent_id,
            agent_access_token=agent_token.token
        )

        # Configurar sesión
        session_update = {
            "type": "session.update",
            "session": {
                "turn_detection": {
                    "type": "azure_semantic_vad",
                    "threshold": 0.3,
                    "prefix_padding_ms": 200,
                    "silence_duration_ms": 300,
                    "remove_filler_words": False,
                    "end_of_utterance_detection": {
                        "model": "semantic_detection_v1",
                        "threshold": 0.01,
                        "timeout": 2,
                    },
                },
                "input_audio_noise_reduction": {
                    "type": "azure_deep_noise_suppression"
                },
                "input_audio_echo_cancellation": {
                    "type": "server_echo_cancellation"
                },
                "voice": {
                    "name": "es-ES-ElviraNeural",  # Voz en español
                    "type": "azure-standard",
                    "temperature": 0.8,
                    "speaking-rate": 1
                },
            },
            "event_id": ""
        }

        self.connection.send(json.dumps(session_update))
        logger.info("Voice session configured")

        # Inicializar reproductor de audio solo si está habilitado
        if self.enable_local_audio:
            logger.info("Initializing local audio player")
            self.audio_player = AudioPlayerAsync()
        else:
            logger.info("Local audio disabled - audio will be sent via callbacks")
            self.audio_player = None

        # Iniciar hilos
        self.stop_event.clear()
        self.is_running = True

        # Hilo para recibir eventos
        self.receive_thread = threading.Thread(target=self._receive_loop)
        self.receive_thread.start()

        return "voice_session_started"

    def send_audio(self, audio_data: bytes):
        """
        Envía datos de audio al servidor

        Args:
            audio_data: Bytes de audio PCM 16-bit, mono, 24kHz
        """
        if not self.is_running or not self.connection:
            raise ValueError("Voice session not running")

        # Codificar audio en base64
        audio_b64 = base64.b64encode(audio_data).decode("utf-8")

        # Enviar al servidor
        message = {
            "type": "input_audio_buffer.append",
            "audio": audio_b64,
            "event_id": ""
        }
        self.connection.send(json.dumps(message))

    def _safe_call_callback(self, callback, *args):
        """
        Llama a un callback de forma segura desde un thread, manejando callbacks síncronos y asíncronos

        Args:
            callback: Función callback (síncrona o asíncrona)
            *args: Argumentos para pasar al callback
        """
        try:
            # Si el callback es una coroutine, lo ejecutamos en el event loop
            if asyncio.iscoroutinefunction(callback):
                if self.event_loop and self.event_loop.is_running():
                    asyncio.run_coroutine_threadsafe(callback(*args), self.event_loop)
                else:
                    logger.warning("Event loop not available for async callback")
            else:
                # Callback síncrono normal
                callback(*args)
        except Exception as e:
            logger.error(f"Error calling callback: {e}")

    def _receive_loop(self):
        """Loop interno para recibir y procesar eventos del servidor"""
        try:
            while not self.stop_event.is_set():
                raw_event = self.connection.recv()
                if raw_event is None:
                    continue

                try:
                    event = json.loads(raw_event)
                    event_type = event.get("type")

                    # Procesar diferentes tipos de eventos
                    if event_type == "session.created":
                        session_id = event.get("session", {}).get("id")
                        logger.info(f"Session created: {session_id}")
                        if self.on_session_created:
                            self._safe_call_callback(self.on_session_created, session_id)

                    elif event_type == "conversation.item.input_audio_transcription.completed":
                        transcript = event.get("transcript", "")
                        logger.info(f"User transcript: {transcript}")
                        if self.on_user_transcript:
                            self._safe_call_callback(self.on_user_transcript, transcript)

                    elif event_type == "response.text.done":
                        text = event.get("text", "")
                        logger.info(f"Agent text: {text}")
                        if self.on_agent_response:
                            self._safe_call_callback(self.on_agent_response, text)

                    elif event_type == "response.audio_transcript.done":
                        transcript = event.get("transcript", "")
                        logger.info(f"Agent audio transcript: {transcript}")
                        if self.on_agent_audio_transcript:
                            self._safe_call_callback(self.on_agent_audio_transcript, transcript)

                    elif event_type == "response.audio.delta":
                        # Decodificar audio
                        audio_b64 = event.get("delta", "")
                        if audio_b64:
                            audio_bytes = base64.b64decode(audio_b64)

                            # Reproducir localmente o enviar via callback
                            if self.audio_player:
                                self.audio_player.add_data(audio_bytes)
                            elif self.on_agent_audio:
                                # Enviar audio al cliente via callback
                                self._safe_call_callback(self.on_agent_audio, audio_bytes)

                    elif event_type == "input_audio_buffer.speech_started":
                        logger.info("User started speaking")
                        # Detener reproducción cuando el usuario habla (solo si hay reproductor local)
                        if self.audio_player:
                            self.audio_player.stop()

                    elif event_type == "error":
                        error_details = event.get("error", {})
                        logger.error(f"Voice Live error: {error_details}")

                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse event: {e}")

        except Exception as e:
            logger.error(f"Error in receive loop: {e}")
        finally:
            logger.info("Receive loop stopped")

    def stop(self):
        """Detiene la sesión de voz y libera recursos"""
        if not self.is_running:
            return

        self.stop_event.set()
        self.is_running = False

        if self.receive_thread:
            self.receive_thread.join(timeout=2)

        if self.audio_player:
            self.audio_player.terminate()
            self.audio_player = None

        if self.connection:
            self.connection.close()
            self.connection = None

        logger.info("Voice session stopped")
