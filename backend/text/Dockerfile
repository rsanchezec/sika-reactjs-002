# Dockerfile para Azure Container Apps
# Optimizado para FastAPI con WebSocket

# Usar imagen oficial de Python slim
FROM python:3.11-slim

# Variables de entorno para Python
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements primero (para aprovechar cache de Docker)
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY assistant_websocket.py .

# NO copiar .env por seguridad - se pasa con --env-file en docker run
COPY .env .env 

# Exponer puerto (Azure Container Apps usa 8000 por defecto)
# Pero se puede cambiar con variable de entorno PORT
EXPOSE 8000

# Health check para Azure
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Usuario no-root por seguridad
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Comando para iniciar la aplicación
# Azure Container Apps establece PORT automáticamente
CMD ["python", "-m", "uvicorn", "assistant_websocket:app", "--host", "0.0.0.0", "--port", "8000"]
