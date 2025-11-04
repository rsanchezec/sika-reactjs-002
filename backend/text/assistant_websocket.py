"""
assistant_websocket.py - API WebSocket para integrar el asistente de Azure AI con React

Este archivo crea un servidor FastAPI con WebSocket que permite al frontend
comunicarse con el asistente de Azure AI usando conversaciones persistentes.

Las conversaciones mantienen el historial entre sesiones.
Optimizado para Azure Container Apps con configuración flexible.
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Optional
import json
import uvicorn
import os
import time
import logging
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# Configurar logging para producción
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="SIKA AI Assistant API",
    description="WebSocket API para asistente AI con Azure",
    version="1.0.0"
)

# Configurar CORS con soporte para múltiples orígenes
# Obtener orígenes permitidos desde variable de entorno (separados por coma)
allowed_origins = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:5173,http://localhost:3000"  # Default para desarrollo
).split(",")

logger.info(f"🌐 CORS configurado para orígenes: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class PersistentChatManager:
    """
    Gestor de sesiones de chat persistentes con Azure AI Assistant

    Solo contiene la lógica esencial para:
    - Gestionar conexiones WebSocket
    - Mantener sesiones persistentes (threads)
    - Enviar/recibir mensajes del asistente
    """

    def __init__(self):
        # Configuración esencial de Azure AI
        self.connection_string = os.getenv("PROJECT_CONNECTION_STRING")
        self.agent_id = os.getenv("AZURE_AGENT_ID")

        # Validar configuración requerida
        if not self.connection_string:
            logger.error("❌ PROJECT_CONNECTION_STRING no está configurado")
            raise ValueError("PROJECT_CONNECTION_STRING es requerido")

        if not self.agent_id:
            logger.error("❌ AZURE_AGENT_ID no está configurado")
            raise ValueError("AZURE_AGENT_ID es requerido")

        # Gestión de sesiones persistentes
        self.user_threads: Dict[str, str] = {}  # {user_id: thread_id}
        self.active_connections: Dict[str, WebSocket] = {}  # {user_id: websocket}

        logger.info(f"✅ Chat Manager inicializado | Agent: {self.agent_id}")

    def _get_client(self):
        """Crea cliente de Azure AI usando SDK 1.0.0b1"""
        return AIProjectClient.from_connection_string(
            credential=DefaultAzureCredential(),
            conn_str=self.connection_string
        )

    async def connect(self, websocket: WebSocket, user_id: str):
        """Conecta usuario y crea/recupera su sesión persistente"""
        try:
            self.active_connections[user_id] = websocket

            # Si ya tiene un thread, recuperarlo; sino, crear uno nuevo
            if user_id in self.user_threads:
                thread_id = self.user_threads[user_id]
                logger.info(f"📂 Sesión recuperada: {user_id}")
            else:
                client = self._get_client()
                with client:
                    thread = client.agents.create_thread()
                    thread_id = thread.id
                self.user_threads[user_id] = thread_id
                logger.info(f"🆕 Nueva sesión: {user_id}")

            return thread_id
        except Exception as e:
            logger.error(f"❌ Error en conexión para {user_id}: {e}")
            return None

    def disconnect(self, user_id: str):
        """Desconecta usuario pero mantiene su sesión persistente"""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
            logger.info(f"🔌 Usuario {user_id} desconectado")

    async def send_to_assistant(self, user_id: str, message: str) -> Optional[str]:
        """Envía mensaje al asistente y obtiene respuesta"""
        try:
            if user_id not in self.user_threads:
                logger.warning(f"⚠️ No hay sesión para {user_id}")
                return None

            thread_id = self.user_threads[user_id]
            client = self._get_client()

            with client:
                # Crear mensaje del usuario
                client.agents.create_message(
                    thread_id=thread_id,
                    role="user",
                    content=message
                )

                # Ejecutar asistente
                run = client.agents.create_run(
                    thread_id=thread_id,
                    agent_id=self.agent_id  # Nota: usa assistant_id en SDK 1.0.0b1
                )

                # Esperar respuesta
                while run.status in ["queued", "in_progress", "requires_action"]:
                    time.sleep(1)
                    run = client.agents.get_run(thread_id=thread_id, run_id=run.id)

                # Verificar estado final
                if run.status == "failed":
                    logger.error(f"❌ Ejecución falló para {user_id}")
                    return None

                # Obtener respuesta
                messages = client.agents.list_messages(thread_id=thread_id)
                response = messages.data[0].content[0].text.value
                logger.info(f"✅ Respuesta generada para {user_id}")
                return response

        except Exception as e:
            logger.error(f"❌ Error enviando mensaje para {user_id}: {e}")
            return None

    def cleanup_user_session(self, user_id: str):
        """Elimina permanentemente la sesión de un usuario"""
        try:
            if user_id not in self.user_threads:
                return False

            thread_id = self.user_threads[user_id]
            client = self._get_client()

            with client:
                client.agents.delete_thread(thread_id=thread_id)

            del self.user_threads[user_id]
            logger.info(f"🗑️ Sesión eliminada: {user_id}")
            return True

        except Exception as e:
            logger.error(f"❌ Error limpiando sesión {user_id}: {e}")
            return False

    def get_stats(self) -> dict:
        """Obtiene estadísticas del sistema"""
        return {
            "agent_id": self.agent_id,
            "active_threads": len(self.user_threads),
            "active_connections": len(self.active_connections),
            "users": list(self.user_threads.keys())
        }


# Crear instancia global del gestor de chat persistente
chat_manager = PersistentChatManager()


@app.get("/")
async def root():
    """Endpoint raíz con información de la API"""
    environment = os.getenv("ENVIRONMENT", "development")
    return {
        "service": "SIKA AI Assistant API",
        "version": "1.0.0",
        "status": "online",
        "environment": environment,
        "endpoints": {
            "websocket": "/ws/chat",
            "health": "/health",
            "stats": "/api/stats",
            "docs": "/docs"
        },
        "active_connections": len(chat_manager.active_connections),
        "persistent_sessions": len(chat_manager.user_threads)
    }


@app.get("/health")
async def health():
    """
    Health check endpoint para Azure Container Apps
    Azure usa este endpoint para verificar que el container está saludable
    """
    try:
        stats = chat_manager.get_stats()
        return {
            "status": "healthy",
            "timestamp": time.time(),
            "stats": stats
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e)
        }


@app.get("/api/stats")
async def get_stats():
    """Endpoint para obtener estadísticas detalladas"""
    return chat_manager.get_stats()


@app.websocket("/ws/chat")
async def websocket_chat_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint para chat persistente con el asistente de Azure AI

    PROTOCOLO DE COMUNICACIÓN:

    1. Cliente se conecta e inicializa sesión:
    {
        "type": "init",
        "user_id": "usuario_123"
    }

    Respuesta:
    {
        "type": "session_ready",
        "message": "Sesión iniciada/recuperada",
        "thread_id": "thread_abc123",
        "is_new_session": true/false
    }

    2. Cliente envía mensaje:
    {
        "type": "message",
        "message": "¿Qué tipo de membrana es Sikalastic-560?"
    }

    Respuesta:
    {
        "type": "bot_message",
        "message": "Respuesta del asistente...",
        "status": "success"
    }

    3. Cliente solicita limpiar sesión (opcional):
    {
        "type": "clear_session"
    }

    Respuesta:
    {
        "type": "session_cleared",
        "message": "Tu historial ha sido eliminado"
    }
    """

    current_user_id = None

    try:
        # Aceptar la conexión WebSocket primero
        await websocket.accept()

        # Esperar mensaje de inicialización
        data = await websocket.receive_text()

        try:
            init_data = json.loads(data)

            if init_data.get("type") != "init":
                error_response = {
                    "type": "error",
                    "message": "Debes enviar un mensaje 'init' primero con tu user_id"
                }
                await websocket.send_text(json.dumps(error_response))
                await websocket.close()
                return

            user_id = init_data.get("user_id", "anonymous_user")
            current_user_id = user_id

            # Verificar si es una sesión existente
            is_new_session = user_id not in chat_manager.user_threads

            # Conectar y crear/recuperar sesión
            thread_id = await chat_manager.connect(websocket, user_id)

            if thread_id:
                response = {
                    "type": "session_ready",
                    "message": "Sesión recuperada. Tu historial está disponible." if not is_new_session else "Nueva sesión creada.",
                    "thread_id": thread_id,
                    "is_new_session": is_new_session,
                    "status": "success"
                }
            else:
                response = {
                    "type": "error",
                    "message": "No se pudo inicializar la sesión",
                    "status": "error"
                }
                await websocket.send_text(json.dumps(response))
                await websocket.close()
                return

            await websocket.send_text(json.dumps(response))

        except json.JSONDecodeError:
            error_response = {
                "type": "error",
                "message": "Formato JSON inválido"
            }
            await websocket.send_text(json.dumps(error_response))
            await websocket.close()
            return

        # Loop principal de mensajes
        while True:
            data = await websocket.receive_text()

            try:
                message_data = json.loads(data)
                message_type = message_data.get("type", "")

                # Procesar mensaje del usuario
                if message_type == "message":
                    user_message = message_data.get("message", "")

                    if not user_message:
                        response = {
                            "type": "error",
                            "message": "Mensaje vacío"
                        }
                        await websocket.send_text(json.dumps(response))
                        continue

                    # Enviar indicador de procesamiento
                    processing_response = {
                        "type": "processing",
                        "message": "Procesando tu mensaje..."
                    }
                    await websocket.send_text(json.dumps(processing_response))

                    # Obtener respuesta del asistente
                    bot_response = await chat_manager.send_to_assistant(current_user_id, user_message)

                    if bot_response:
                        response = {
                            "type": "bot_message",
                            "message": bot_response,
                            "status": "success"
                        }
                    else:
                        response = {
                            "type": "error",
                            "message": "No se pudo obtener respuesta del asistente",
                            "status": "error"
                        }

                    await websocket.send_text(json.dumps(response))

                # Limpiar sesión del usuario
                elif message_type == "clear_session":
                    success = chat_manager.cleanup_user_session(current_user_id)

                    if success:
                        response = {
                            "type": "session_cleared",
                            "message": "Tu historial de conversación ha sido eliminado permanentemente."
                        }
                    else:
                        response = {
                            "type": "error",
                            "message": "No se pudo limpiar la sesión"
                        }

                    await websocket.send_text(json.dumps(response))

                # Obtener estadísticas
                elif message_type == "get_stats":
                    stats = chat_manager.get_stats()
                    response = {
                        "type": "stats",
                        "data": stats
                    }
                    await websocket.send_text(json.dumps(response))

                # Tipo desconocido
                else:
                    response = {
                        "type": "error",
                        "message": f"Tipo de mensaje desconocido: {message_type}"
                    }
                    await websocket.send_text(json.dumps(response))

            except json.JSONDecodeError:
                error_response = {
                    "type": "error",
                    "message": "Formato JSON inválido"
                }
                await websocket.send_text(json.dumps(error_response))

            except Exception as e:
                error_response = {
                    "type": "error",
                    "message": f"Error procesando mensaje: {str(e)}"
                }
                await websocket.send_text(json.dumps(error_response))

    except WebSocketDisconnect:
        logger.info(f"🔌 Cliente desconectado: {current_user_id}")
        if current_user_id:
            chat_manager.disconnect(current_user_id)

    except Exception as e:
        logger.error(f"❌ Error en WebSocket para {current_user_id}: {e}")
        if current_user_id:
            chat_manager.disconnect(current_user_id)


if __name__ == "__main__":
    # Configuración desde variables de entorno
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    environment = os.getenv("ENVIRONMENT", "development")
    reload = environment == "development"

    logger.info("\n" + "="*60)
    logger.info("🚀 SIKA AI Assistant - Persistent Sessions API")
    logger.info("="*60)
    logger.info(f"📍 Environment: {environment}")
    logger.info(f"📍 Host: {host}")
    logger.info(f"📍 Port: {port}")
    logger.info(f"🔌 WebSocket: ws://{host}:{port}/ws/chat")
    logger.info(f"📊 Health: http://{host}:{port}/health")
    logger.info(f"📈 Stats: http://{host}:{port}/api/stats")
    logger.info(f"📚 Docs: http://{host}:{port}/docs")
    logger.info("="*60)
    logger.info("💾 Las conversaciones se mantienen entre sesiones")
    logger.info("🔄 Los usuarios pueden recuperar su historial")
    logger.info("="*60 + "\n")

    uvicorn.run(
        "assistant_websocket:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info"
    )
