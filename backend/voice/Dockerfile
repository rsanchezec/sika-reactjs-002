# Dockerfile para Azure Container Apps - Servicio de Voz
# Optimizado para FastAPI con WebSocket y Azure Voice Live

# Usar imagen oficial de Python slim
FROM python:3.11-slim

# Variables de entorno para Python
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalar dependencias del sistema necesarias para audio
RUN apt-get update && apt-get install -y \
    libportaudio2 \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements primero (para aprovechar cache de Docker)
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY voice_websocket.py .
COPY voice_manager.py .

# NO copiar .env por seguridad - se pasa con --env-file en docker run
COPY .env .env

# Exponer puerto 8001 (puerto del servicio de voz)
EXPOSE 8001

# Health check para Azure
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8001/health')" || exit 1

# Usuario no-root por seguridad
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Comando para iniciar la aplicación
CMD ["python", "-m", "uvicorn", "voice_websocket:app", "--host", "0.0.0.0", "--port", "8001"]
