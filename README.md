# SIKA AI Assistant - Aplicación Completa

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109-green.svg)](https://fastapi.tiangolo.com/)
[![React](https://img.shields.io/badge/React-18.3-61DAFB.svg)](https://reactjs.org/)
[![Vite](https://img.shields.io/badge/Vite-6.0-646CFF.svg)](https://vitejs.dev/)
[![Azure](https://img.shields.io/badge/Azure-Container%20Apps-0078D4.svg)](https://azure.microsoft.com/en-us/products/container-apps/)
[![WebSocket](https://img.shields.io/badge/WebSocket-Real--time-orange.svg)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)

Aplicación completa de asistente de IA con **frontend React** y **backend FastAPI**. Incluye comunicación WebSocket en tiempo real para modo texto (chat) y **conversación por voz en tiempo real** usando Azure Voice Live API. Desplegado en Azure Container Apps.

---

## Tabla de Contenidos

- [Características](#características)
- [Arquitectura](#arquitectura)
- [Tecnologías](#tecnologías)
- [🎨 Frontend (React + Vite)](#-frontend-react--vite)
  - [Características del Frontend](#características-del-frontend)
  - [Estructura del Frontend](#estructura-del-frontend)
  - [Configuración Local del Frontend](#configuración-local-del-frontend)
  - [Build y Deployment del Frontend](#build-y-deployment-del-frontend)
  - [Scripts de Deployment a Azure](#scripts-de-deployment-a-azure)
- [Requisitos Previos](#requisitos-previos)
- [Instalación y Configuración Local](#instalación-y-configuración-local)
- [Despliegue en Azure (Texto)](#despliegue-en-azure)
  - [azure-setup.sh](#azure-setupsh---configuración-inicial)
  - [deploy.sh](#deploysh---despliegue-continuo)
- [🎙️ Servicio de Voz (Voice Live API)](#️-servicio-de-voz-voice-live-api)
  - [Características Principales](#características-principales)
  - [Arquitectura del Servicio de Voz](#arquitectura-del-servicio-de-voz)
  - [Componentes Principales](#componentes-principales)
  - [Variables de Entorno Adicionales](#variables-de-entorno-adicionales)
  - [Instalación Local del Servicio de Voz](#instalación-local-del-servicio-de-voz)
  - [Protocolo WebSocket de Voz](#protocolo-websocket-de-voz)
  - [Ejemplo de Cliente JavaScript](#ejemplo-de-cliente-javascript)
  - [Despliegue en Azure del Servicio de Voz](#despliegue-en-azure-del-servicio-de-voz)
  - [Troubleshooting del Servicio de Voz](#troubleshooting-del-servicio-de-voz)
  - [Comparación: Texto vs Voz](#comparación-texto-vs-voz)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Variables de Entorno](#variables-de-entorno)
- [API y Endpoints](#api-y-endpoints)
- [Protocolo WebSocket](#protocolo-websocket)
- [Testing](#testing)
- [Monitoreo y Logs](#monitoreo-y-logs)
- [Seguridad](#seguridad)
- [Troubleshooting](#troubleshooting)
- [Costos Estimados](#costos-estimados)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

---

## Características

### Frontend (React + Vite)
- **💬 Interfaz de Chat Moderna**: UI intuitiva con diseño inspirado en ChatGPT
- **🎤 Modo Voz Integrado**: Alternancia entre modo texto y voz con un click
- **🔊 Reproducción de Audio Continua**: Sistema optimizado para streaming de audio sin cortes
- **📝 Indicadores de Procesamiento**: Feedback visual durante las respuestas del bot
- **🎨 Diseño Responsive**: Adaptable a dispositivos móviles y desktop
- **⚡ Vite Hot Reload**: Desarrollo rápido con recarga instantánea
- **🐳 Docker Multi-Stage Build**: Imagen optimizada con Nginx para producción
- **🌐 Variables de Entorno**: Configuración flexible para desarrollo y producción
- **📦 Build Optimizado**: Bundle minificado para máximo rendimiento

### Backend de Texto (Chat)
- **Comunicación WebSocket en Tiempo Real**: Conexión bidireccional persistente para interacción inmediata
- **Gestión de Sesiones Persistentes**: Mantiene el historial de conversaciones entre reconexiones
- **Integración con Azure AI**: Utiliza Azure AI Projects SDK y GPT-4 para respuestas inteligentes
- **Auto-escalado**: Configurado para escalar de 1 a 3 réplicas según demanda
- **Zero-Downtime Deployments**: Actualizaciones sin interrupciones del servicio
- **Health Checks**: Endpoints de monitoreo para Azure Container Apps
- **CORS Configurable**: Soporte para múltiples orígenes frontend

### Backend de Voz (Voice Live)
- **🎙️ Conversación por Voz en Tiempo Real**: Integración con Azure Voice Live API
- **🗣️ Detección Semántica de Voz (VAD)**: Azure Semantic VAD para detección inteligente de turnos
- **🎧 Cancelación de Eco y Ruido**: Deep Noise Suppression y Echo Cancellation integrados
- **📝 Transcripciones en Tiempo Real**: Transcripciones automáticas de usuario y agente
- **🔊 Audio Streaming Bidireccional**: Envío y recepción de audio PCM 16-bit, mono, 24kHz
- **🌐 Voz en Español**: Configurado con `es-ES-ElviraNeural` de Azure Neural TTS
- **🔄 Mismo Contexto que Chat**: Usa el mismo agente de Azure AI para mantener coherencia

### Infraestructura
- **Arquitectura Cloud-Native**: Diseñado específicamente para Azure Container Apps
- **Autenticación Azure**: Soporta Managed Identity y Service Principal
- **Documentación Swagger**: API docs interactiva en `/docs`

---

## Arquitectura

### Arquitectura Completa (Texto + Voz)

```
┌──────────────────────────────────────────────────────────────┐
│                    Frontend App (React)                      │
│                                                              │
│  ┌──────────────────────┐     ┌──────────────────────────┐ │
│  │   Modo Texto (Chat)  │     │   Modo Voz (Voice Live)  │ │
│  │   WebSocket Client   │     │   WebSocket + Audio      │ │
│  └──────────┬───────────┘     └───────────┬──────────────┘ │
└─────────────┼─────────────────────────────┼─────────────────┘
              │                             │
              │ WSS                         │ WSS + PCM Audio
              │ /ws/chat                    │ /ws/voice
              │                             │
┌─────────────▼─────────────────────────────▼─────────────────┐
│           Azure Container Apps (Auto-scaling)                │
│                                                              │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │  Text API (Port 8000)   │  │  Voice API (Port 8001)   │  │
│  │  ─────────────────────  │  │  ──────────────────────  │  │
│  │  FastAPI + Uvicorn      │  │  FastAPI + Uvicorn       │  │
│  │                         │  │                          │  │
│  │  ┌──────────────────┐   │  │  ┌───────────────────┐  │  │
│  │  │PersistentChat    │   │  │  │VoiceConnection    │  │  │
│  │  │Manager           │   │  │  │Manager            │  │  │
│  │  │                  │   │  │  │                   │  │  │
│  │  │- WebSocket conns │   │  │  │- Voice sessions   │  │  │
│  │  │- Session mapping │   │  │  │- Audio streaming  │  │  │
│  │  │- Azure AI client │   │  │  │- VoiceManager     │  │  │
│  │  └──────────────────┘   │  │  └───────────────────┘  │  │
│  └─────────┬───────────────┘  └────────────┬─────────────┘  │
└────────────┼──────────────────────────────┼─────────────────┘
             │                              │
             │ Azure AI SDK                 │ Voice Live WebSocket
             │                              │
┌────────────▼──────────────────────────────▼─────────────────┐
│                    Azure AI Services                         │
│                                                              │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │  AI Projects Hub        │  │  Voice Live API          │  │
│  │  ─────────────────────  │  │  ──────────────────────  │  │
│  │  - Agents API           │  │  - Real-time Voice       │  │
│  │  - GPT-4 Deployment     │  │  - Semantic VAD          │  │
│  │  - Conversation Threads │  │  - Noise Suppression     │  │
│  │  - Thread Storage       │  │  - Echo Cancellation     │  │
│  │                         │  │  - Neural TTS (Español)  │  │
│  └─────────────────────────┘  └──────────────────────────┘  │
│                 ▲                                            │
│                 └──────────── Same Agent ID ─────────────────┘
└──────────────────────────────────────────────────────────────┘
```

### Flujo de Comunicación - Modo Texto

1. Cliente conecta vía WebSocket (`/ws/chat`)
2. Envía mensaje de inicialización con `user_id`
3. Sistema recupera o crea thread de conversación
4. Mensajes del usuario se envían al agente Azure AI
5. Respuestas se transmiten en tiempo real al cliente
6. Historial persiste en Azure AI Thread Storage

### Flujo de Comunicación - Modo Voz

1. Cliente conecta vía WebSocket (`/ws/voice`)
2. Envía mensaje de inicialización con `user_id` y `type: init_voice`
3. Backend establece conexión con Azure Voice Live API
4. Cliente captura audio del micrófono y lo envía como bytes PCM
5. Azure Voice Live procesa el audio con VAD, transcribe y envía al agente
6. Agente genera respuesta de texto
7. Azure Neural TTS convierte texto a audio (es-ES-ElviraNeural)
8. Backend transmite audio al cliente en tiempo real
9. Cliente reproduce el audio mientras recibe las transcripciones

---

## Tecnologías

### Backend
- **FastAPI** `0.109.0` - Framework web asíncrono moderno
- **Uvicorn** `0.27.0` - Servidor ASGI con soporte WebSocket
- **WebSockets** `12.0` - Comunicación en tiempo real
- **Python** `3.11+` - Lenguaje de programación

### Azure Services
- **Azure Container Apps** - Hosting serverless de contenedores
- **Azure Container Registry** - Registro privado de imágenes Docker
- **Azure AI Projects SDK** `1.0.0b10` - Orquestación de agentes IA
- **Azure Identity** `1.22.0` - Autenticación y credenciales
- **Azure Search Documents** `11.4.0` - Capacidades de búsqueda

### Seguridad y Utilidades
- **python-jose[cryptography]** `3.3.0` - Manejo de JWT
- **python-dotenv** `1.0.0` - Gestión de variables de entorno
- **DefaultAzureCredential** - Soporte para Managed Identity

### DevOps
- **Docker** - Contenedorización
- **Azure CLI** - Automatización de despliegues
- **Bash Scripts** - Scripts de setup y deploy

---

## 🎨 Frontend (React + Vite)

El frontend de SIKA AI Assistant es una aplicación React moderna construida con Vite, optimizada para comunicación WebSocket en tiempo real con los backends de texto y voz.

### Características del Frontend

#### 🎯 Modos de Interacción

- **Modo Texto (Chat)**:
  - Interfaz de chat con mensajes del usuario y bot
  - Input de texto con soporte para Enter para enviar
  - Indicador visual "Procesando tu mensaje..." mientras el bot responde
  - Historial de conversación con scroll automático
  - Botón para limpiar historial completo

- **Modo Voz**:
  - Activación con un solo click en el botón del micrófono
  - Captura de audio del micrófono en tiempo real
  - Transcripción en vivo de lo que el usuario dice
  - Reproducción continua del audio del bot (sin cortes)
  - Indicador "SIKA está pensando..." durante procesamiento
  - Sistema de audio optimizado con Web Audio API

#### 🎨 Diseño y UX

- **Interfaz Moderna**:
  - Diseño limpio inspirado en ChatGPT
  - Indicador de estado de conexión (Conectado/Desconectado/Reconectando)
  - Session ID visible para tracking
  - Mensajes diferenciados visualmente (usuario/bot/sistema/error)

- **Responsive**:
  - Adaptable a móviles, tablets y desktop
  - CSS Grid y Flexbox para layouts fluidos

#### ⚡ Performance

- **Build Optimizado**:
  - Bundle minificado con Vite
  - Code splitting automático
  - Assets optimizados (CSS + JS)
  - Gzip compression habilitada en Nginx

- **Audio Streaming**:
  - Reproducción continua sin cortes entre chunks
  - Programación secuencial de buffers de audio
  - Conversión PCM 16-bit optimizada
  - Web Audio API con `AudioContext` de 24kHz

### Estructura del Frontend

```
frontend/
│
├── src/
│   ├── components/
│   │   ├── ChatInterface.jsx      # 📱 Componente principal (600+ líneas)
│   │   │                          #    - Estado de conexiones WebSocket
│   │   │                          #    - Captura y envío de audio
│   │   │                          #    - Reproducción de audio recibido
│   │   │                          #    - Gestión de mensajes
│   │   │                          #    - UI de chat y controles de voz
│   │   │
│   │   └── ChatInterface.css      # 🎨 Estilos del componente
│   │                              #    - Diseño del chat
│   │                              #    - Animaciones (typing indicator)
│   │                              #    - Responsive design
│   │
│   ├── App.jsx                    # 🚀 Componente raíz de React
│   ├── App.css                    # 🎨 Estilos globales de la app
│   ├── main.jsx                   # 🔧 Entry point de React
│   └── index.css                  # 🎨 Estilos base (reset, variables)
│
├── public/                        # 📁 Archivos estáticos públicos
│
├── dist/                          # 📦 Build de producción (generado)
│   ├── index.html                 #    - HTML principal
│   └── assets/                    #    - JS y CSS minificados
│
├── .env.development               # 🔧 Variables para desarrollo (localhost)
│   # VITE_WS_TEXT_URL=ws://localhost:8000/ws/chat
│   # VITE_WS_VOICE_URL=ws://localhost:8001/ws/voice
│
├── .env.production                # 🌐 Variables para producción (Azure)
│   # VITE_WS_TEXT_URL=wss://sika-text-api.azurecontainerapps.io/ws/chat
│   # VITE_WS_VOICE_URL=wss://sika-voice-api.azurecontainerapps.io/ws/voice
│
├── package.json                   # 📦 Dependencias y scripts npm
│   # - react: 18.3.1
│   # - react-dom: 18.3.1
│   # - vite: 6.0.0
│
├── vite.config.js                 # ⚙️ Configuración de Vite
├── index.html                     # 📄 HTML template
│
├── Dockerfile                     # 🐳 Docker multi-stage build
│   # Stage 1: Build con Node.js 18
│   # Stage 2: Serve con Nginx
│
├── nginx.conf                     # 🌐 Configuración de Nginx
│   # - Serve archivos estáticos
│   # - Fallback a index.html para React Router
│   # - Compresión gzip habilitada
│
├── .dockerignore                  # 🚫 Exclusiones para Docker build
│
├── azure-setup-fixed.sh           # 🏗️ Setup inicial en Azure
│   # - Crea Container App para frontend
│   # - Build con URLs de backend en .env.production
│   # - Push a Azure Container Registry
│   # - Puerto 80 (Nginx)
│
├── deploy.sh                      # 🚢 Deployment continuo
│   # - Rebuild con URLs de backend
│   # - Versionado con timestamp
│   # - Update del Container App
│
├── logs.sh                        # 📋 Ver logs de Azure
│
├── DEPLOYMENT.md                  # 📚 Guía completa de deployment
│   # - Instrucciones paso a paso
│   # - Comandos útiles
│   # - Troubleshooting
│
└── test_websocket.html            # 🧪 Cliente de prueba standalone
    # - Pruebas de conexión WebSocket
    # - Testing de audio bidireccional
```

### Configuración Local del Frontend

#### 1. Prerrequisitos

```bash
# Node.js 18+ requerido
node --version  # v18.x.x o superior
npm --version   # 9.x.x o superior
```

#### 2. Instalar Dependencias

```bash
cd frontend
npm install
```

**Dependencias instaladas**:
- `react` (18.3.1) - Librería UI
- `react-dom` (18.3.1) - Renderizado DOM
- `vite` (6.0.0) - Build tool y dev server
- `@vitejs/plugin-react` (4.3.4) - Plugin de Vite para React

#### 3. Configurar Variables de Entorno

El proyecto ya incluye `.env.development` y `.env.production` configurados:

**`.env.development` (para desarrollo local)**:
```env
VITE_WS_TEXT_URL=ws://localhost:8000/ws/chat
VITE_WS_VOICE_URL=ws://localhost:8001/ws/voice
```

**`.env.production` (para Azure)**:
```env
VITE_WS_TEXT_URL=wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat
VITE_WS_VOICE_URL=wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice
```

**Nota**: Solo las variables con prefijo `VITE_` son accesibles en el código cliente.

#### 4. Ejecutar en Modo Desarrollo

```bash
npm run dev
```

**Salida esperada**:
```
VITE v6.4.1  ready in 123 ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
➜  press h + enter to show help
```

**Características del modo desarrollo**:
- ⚡ Hot Module Replacement (HMR) - Cambios instantáneos sin reload
- 🔧 Source maps para debugging
- 🚀 Servidor de desarrollo ultra-rápido
- 📝 Mensajes de error detallados

#### 5. Verificar Funcionamiento

1. Abre `http://localhost:5173/`
2. Verifica que aparece la interfaz del chat
3. Asegúrate de que los backends estén corriendo:
   - Texto: `http://localhost:8000`
   - Voz: `http://localhost:8001`
4. El status debe mostrar "Conectado"

### Build y Deployment del Frontend

#### Build Local para Testing

```bash
# Build de producción
npm run build

# Output en /dist:
#   dist/
#   ├── index.html (0.41 KB)
#   ├── assets/
#   │   ├── index-CHbtFizT.css (4.53 KB)
#   │   └── index-BwvcG5TI.js (152.77 KB gzipped: 49.32 KB)
```

**Características del build**:
- ✅ Minificación de JS y CSS
- ✅ Tree-shaking (elimina código no usado)
- ✅ Code splitting automático
- ✅ Assets con hash para cache busting
- ✅ Source maps de producción

#### Preview del Build

```bash
# Servir el build de producción localmente
npm run preview

# Abre: http://localhost:4173/
```

**Uso**: Verificar que el build funciona correctamente antes de desplegar a Azure.

#### Docker Build Local

```bash
# Build de la imagen Docker con URLs de Azure
docker build \
  --build-arg VITE_WS_TEXT_URL=wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat \
  --build-arg VITE_WS_VOICE_URL=wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice \
  -t sika-frontend .

# Run localmente
docker run -d -p 8080:80 --name sika-frontend-local sika-frontend

# Test: http://localhost:8080
```

### Scripts de Deployment a Azure

El frontend incluye scripts automatizados para deployment en Azure Container Apps.

#### 1. `azure-setup-fixed.sh` - Setup Inicial

**Propósito**: Crear toda la infraestructura Azure para el frontend (primera vez).

**¿Qué hace?**:
1. ✅ Crea/verifica Resource Group (`sika-container-rg`)
2. ✅ Crea/verifica Azure Container Registry (`sikaregistrytext`)
3. ✅ Crea/verifica Container App Environment (`sika-environment`)
4. ✅ Build de la imagen Docker con URLs de backend de `.env.production`
5. ✅ Push a Azure Container Registry
6. ✅ Crea Container App del frontend con configuración:
   - Puerto: 80 (Nginx)
   - CPU: 0.25 vCPU
   - Memoria: 0.5 GB
   - Réplicas: 1-5 (auto-scaling)
   - Ingress: External (HTTPS automático)
7. ✅ Devuelve URL pública del frontend

**Ejecución**:
```bash
cd frontend

# Git Bash (Windows) o Terminal (Linux/Mac)
chmod +x azure-setup-fixed.sh
./azure-setup-fixed.sh
```

**Variables configurables** (editar en el script):
```bash
RESOURCE_GROUP="sika-container-rg"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-frontend-app"
ENVIRONMENT_NAME="sika-environment"
BACKEND_TEXT_URL="wss://sika-assistant-text-api...azurecontainerapps.io/ws/chat"
BACKEND_VOICE_URL="wss://sika-assistant-voice-api...azurecontainerapps.io/ws/voice"
```

**Tiempo estimado**: ~8-10 minutos

**Output esperado**:
```
✅ Setup completado exitosamente!

🌐 URL de tu frontend:
  App: https://sika-assistant-frontend-app.XXXXX.eastus.azurecontainerapps.io

🔗 Se conecta a estos backends:
  Text API: wss://sika-assistant-text-api...azurecontainerapps.io/ws/chat
  Voice API: wss://sika-assistant-voice-api...azurecontainerapps.io/ws/voice
```

#### 2. `deploy.sh` - Deployments Posteriores

**Propósito**: Actualizar el frontend con nuevos cambios (no recrea infraestructura).

**¿Qué hace?**:
1. ✅ Build de nueva imagen Docker con URLs de backend
2. ✅ Tag con timestamp (`v20251105-143022`) + `latest`
3. ✅ Push de ambas imágenes a ACR
4. ✅ Update del Container App con la nueva imagen
5. ✅ Muestra URL actualizada y versión desplegada

**Ejecución**:
```bash
cd frontend
./deploy.sh
```

**Tiempo estimado**: ~3-5 minutos

**Output esperado**:
```
✅ Deployment completado exitosamente!

📦 Versión desplegada:
  Image: sikaregistrytext.azurecr.io/sika-assistant-frontend:v20251105-143022

🌐 URL del frontend:
  https://sika-assistant-frontend-app.XXXXX.eastus.azurecontainerapps.io

🔗 Conectado a:
  Text API: wss://...
  Voice API: wss://...
```

#### 3. `logs.sh` - Ver Logs

**Propósito**: Ver logs del frontend en tiempo real.

**Ejecución**:
```bash
cd frontend
./logs.sh

# O manualmente:
az containerapp logs show \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --follow
```

**Uso**: Debugging de problemas en producción.

### Comandos Útiles para el Frontend

#### Ver información del Container App

```bash
az containerapp show \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv
```

#### Listar revisiones (deployments)

```bash
az containerapp revision list \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --output table
```

#### Rollback a una versión anterior

```bash
# 1. Listar revisiones
az containerapp revision list --name sika-assistant-frontend-app --resource-group sika-container-rg --output table

# 2. Activar revisión específica
az containerapp revision set-mode \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --mode single \
  --revision sika-assistant-frontend-app--REVISION-NAME
```

#### Escalar el frontend

```bash
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --min-replicas 2 \
  --max-replicas 10
```

#### Reiniciar el Container App

```bash
az containerapp revision restart \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg
```

### Troubleshooting del Frontend

#### La página carga pero dice "Desconectado"

**Causa**: Los backends no están corriendo o las URLs son incorrectas.

**Solución**:
```bash
# 1. Verificar que los backends están activos
curl https://sika-assistant-text-api...azurecontainerapps.io/health
curl https://sika-assistant-voice-api...azurecontainerapps.io/health

# 2. Verificar URLs en el build desplegado
az containerapp revision list --name sika-assistant-frontend-app --resource-group sika-container-rg --output table

# 3. Revisar logs
./logs.sh

# 4. Verificar en la consola del navegador (F12 → Console)
# Debe mostrar: "🔧 Configuración WebSocket: - Texto: wss://..."
```

#### Cambios no se reflejan después de deploy

**Solución**:
```bash
# 1. Hacer hard refresh en el navegador
# Chrome/Edge: Ctrl + Shift + R
# Firefox: Ctrl + F5

# 2. Limpiar caché del navegador

# 3. Verificar que el deployment se completó
az containerapp revision list --name sika-assistant-frontend-app --resource-group sika-container-rg --output table

# 4. Forzar restart
az containerapp revision restart --name sika-assistant-frontend-app --resource-group sika-container-rg
```

#### El audio se escucha entrecortado (modo voz)

**Causa**: Latencia de red o problema en la reproducción de chunks de audio.

**Solución**: El código ya está optimizado con reproducción secuencial. Si persiste:
1. Verificar conexión a internet (latencia <200ms recomendada)
2. Abrir DevTools → Console y buscar errores de audio
3. Verificar que el navegador soporta Web Audio API
4. Probar con auriculares en vez de altavoces

#### Error en Docker build

**Problema**: El build falla con "nginx.conf not found" o ".env.production not found"

**Causa**: `.dockerignore` bloqueando archivos necesarios.

**Solución**:
```bash
# Verificar .dockerignore (ya está corregido)
cat .dockerignore

# Debe permitir:
# - nginx.conf
# - .env.production
# - .env.development

# Forzar rebuild sin cache
docker build --no-cache \
  --build-arg VITE_WS_TEXT_URL=wss://... \
  --build-arg VITE_WS_VOICE_URL=wss://... \
  -t sika-frontend .
```

### Costos del Frontend en Azure

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Container App** | 1 réplica 24/7, 0.25vCPU, 0.5GB | ~$20-25/mes |
| **Egress Data Transfer** | Primeros 100GB gratis | $0-5/mes |
| **Container Registry** | Compartido con backends | $0 (ya incluido) |
| **HTTPS Certificate** | Automático por Azure | Gratis |
| **Total Frontend** | | **~$20-30/mes** |

**Optimización de costos**:
```bash
# Escalar a 0 réplicas fuera de horario (ahorra ~70%)
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --min-replicas 0 \
  --max-replicas 3
```

**Nota**: El frontend es app estática (HTML/CSS/JS), consume muy pocos recursos. Los costos principales son de los backends.

---

## Requisitos Previos

### Software Necesario

- **Python 3.11 o superior** - [Descargar](https://www.python.org/downloads/)
- **Docker Desktop** - [Descargar](https://www.docker.com/products/docker-desktop)
- **Azure CLI** - [Descargar](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Git Bash** o **WSL** (para ejecutar scripts `.sh` en Windows) - [Descargar Git Bash](https://git-scm.com/downloads)

### Recursos Azure

- Suscripción activa de Azure
- Azure AI Project creado en [Azure AI Studio](https://ai.azure.com)
- Agente de IA configurado y desplegado
- Permisos para crear recursos (Resource Groups, Container Apps, ACR)

### Credenciales Requeridas

Antes de iniciar, obtén:
- `PROJECT_CONNECTION_STRING` de tu Azure AI Project
- `AZURE_AGENT_ID` de tu agente configurado (formato: `asst_xxxxx`)
- URL de tu aplicación frontend para configurar CORS

---

## Instalación y Configuración Local

### 1. Clonar y Navegar al Proyecto

```bash
cd C:\Axxon\sika-proyect\backend\text
```

### 2. Crear Entorno Virtual

**Opción Windows (CMD/PowerShell):**
```cmd
python -m venv .venv
.venv\Scripts\activate
```

**Opción Windows (Git Bash):**
```bash
python -m venv .venv
source .venv/Scripts/activate
```

**Verificar activación:**
```bash
python --version  # Debe mostrar Python 3.11+
which python      # Debe apuntar a .venv
```

### 3. Instalar Dependencias

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### 4. Configurar Variables de Entorno

**Copiar plantilla:**
```bash
copy .env.example .env  # Windows CMD
# o
cp .env.example .env    # Git Bash
```

**Editar `.env` con tus credenciales:**
```env
PROJECT_CONNECTION_STRING=<tu_connection_string_de_azure_ai>
AZURE_AGENT_ID=asst_<tu_agent_id>
MODEL_DEPLOYMENT_NAME=gpt-4
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
HOST=0.0.0.0
PORT=8000
ENVIRONMENT=development
```

### 5. Ejecutar el Servidor Localmente

**Opción 1: Ejecutar directamente**
```bash
python assistant_websocket.py
```

**Opción 2: Con Uvicorn (recomendado para desarrollo)**
```bash
uvicorn assistant_websocket:app --reload --host 0.0.0.0 --port 8000
```

**Verificar que funciona:**
- Abrir navegador en: http://localhost:8000
- Ver documentación: http://localhost:8000/docs
- Verificar health: http://localhost:8000/health

### 6. Probar con Cliente WebSocket

Abrir `test_websocket.html` en tu navegador para probar la conexión WebSocket interactivamente.

---

## Despliegue en Azure

### Preparación en Windows

Los scripts `azure-setup.sh` y `deploy.sh` son scripts de Bash. En Windows, debes ejecutarlos usando **Git Bash** o **WSL**.

**Abrir Git Bash:**
1. Click derecho en la carpeta del proyecto
2. Seleccionar "Git Bash Here"
3. O abrir Git Bash y navegar: `cd /c/Axxon/sika-proyect/backend/text`

**Dar permisos de ejecución (solo primera vez):**
```bash
chmod +x azure-setup.sh
chmod +x deploy.sh
```

---

### `azure-setup.sh` - Configuración Inicial

**Propósito:** Script de configuración única que crea toda la infraestructura Azure necesaria.

**¿Cuándo ejecutarlo?**
- Primera vez que despliegas el proyecto
- Cuando necesites recrear toda la infraestructura
- Para crear un nuevo ambiente (dev/staging/prod)

**¿Qué hace este script?**

1. **Verificación Inicial**
   - Valida que estés autenticado en Azure CLI
   - Muestra tu suscripción activa
   - Solicita confirmación antes de crear recursos

2. **Creación de Recursos Azure**
   - **Resource Group**: `sika-container-rg` (contenedor lógico)
   - **Container Registry**: `sikaregistrytext` (registro privado de imágenes)
   - **Container App Environment**: `sika-environment` (entorno de ejecución)

3. **Configuración de Seguridad**
   - Solicita interactivamente variables sensibles:
     - `PROJECT_CONNECTION_STRING` (conexión a Azure AI)
     - `AZURE_AGENT_ID` (ID del agente)
     - `FRONTEND_URL` (para CORS)
   - Almacena credenciales como secretos de Azure

4. **Build y Despliegue**
   - Construye imagen Docker localmente
   - Sube imagen a Azure Container Registry
   - Crea Container App con configuración:
     - **Ingress externo** en puerto 8000
     - **Auto-scaling**: 1-3 réplicas
     - **Recursos**: 0.5 vCPU, 1GB RAM
     - **Health check**: `/health`
     - **Variables de entorno** para producción

5. **Post-despliegue**
   - Muestra URLs del servicio:
     - API Base
     - WebSocket
     - Health Check
     - Swagger Docs
   - Imprime credenciales de ACR
   - Proporciona comandos para monitoreo

**Cómo ejecutar:**

```bash
# En Git Bash o WSL
cd /c/Axxon/sika-proyect/backend/text

# Autenticarse en Azure (si no lo has hecho)
az login

# Seleccionar suscripción correcta (si tienes múltiples)
az account set --subscription "<nombre_o_id_suscripcion>"

# Ejecutar script de setup
./azure-setup.sh
```

**Entrada requerida durante ejecución:**
```
Enter PROJECT_CONNECTION_STRING: <pegar_tu_connection_string>
Enter AZURE_AGENT_ID: asst_xxxxxxxxxxxxx
Enter FRONTEND_URL: https://tuapp.azurewebsites.net
```

**Tiempo estimado:** 8-12 minutos

**Salida esperada:**
```
=== DEPLOYMENT COMPLETE ===

Your API is available at:
- API Base: https://sika-assistant-text-api.xxx.eastus.azurecontainerapps.io
- WebSocket: wss://sika-assistant-text-api.xxx.eastus.azurecontainerapps.io/ws/chat
- Health: https://sika-assistant-text-api.xxx.eastus.azurecontainerapps.io/health
- Docs: https://sika-assistant-text-api.xxx.eastus.azurecontainerapps.io/docs
```

**Importante:** Guarda la URL del servicio para configurar tu frontend.

---

### `deploy.sh` - Despliegue Continuo

**Propósito:** Script de despliegue rápido para actualizar el código sin recrear infraestructura.

**¿Cuándo ejecutarlo?**
- Después de hacer cambios en el código
- Para actualizar la aplicación en producción
- Despliegues continuos en tu pipeline CI/CD

**¿Qué hace este script?**

1. **Validación**
   - Verifica autenticación en Azure CLI
   - Confirma que el usuario está listo para desplegar

2. **Build con Versionado**
   - Construye nueva imagen Docker
   - Genera tag con timestamp: `v20250103-143022`
   - Etiqueta también como `:latest` para referencia

3. **Push a Registry**
   - Autentica con Azure Container Registry
   - Sube imagen versionada y latest a ACR

4. **Actualización de Container App**
   - Actualiza Container App con nueva imagen
   - Azure realiza rolling update (zero-downtime)
   - Mantiene configuración y secretos existentes

5. **Verificación**
   - Obtiene URL del servicio (FQDN)
   - Muestra URLs actualizadas
   - Imprime versión desplegada (para rollback si es necesario)
   - Opcionalmente muestra logs en vivo

**Cómo ejecutar:**

```bash
# En Git Bash o WSL
cd /c/Axxon/sika-proyect/backend/text

# Asegurarse de estar autenticado
az login

# Ejecutar despliegue
./deploy.sh
```

**Tiempo estimado:** 3-5 minutos

**Salida esperada:**
```
Building image with tag: v20250103-143022
[+] Building 45.2s...
Image pushed successfully
Updating Container App...
=== DEPLOYMENT COMPLETE ===

Your updated API is available at:
- API Base: https://sika-assistant-api.xxx.eastus.azurecontainerapps.io
- WebSocket: wss://sika-assistant-api.xxx.eastus.azurecontainerapps.io/ws/chat
- Health: https://sika-assistant-api.xxx.eastus.azurecontainerapps.io/health

Deployed image tag: v20250103-143022
```

**Rollback (si es necesario):**
```bash
az containerapp update \
  --name sika-assistant-api \
  --resource-group sika-resources \
  --image sikaregistry.azurecr.io/sika-assistant:v20250103-100000
```

---

### Diferencias entre Scripts

| Aspecto | azure-setup.sh | deploy.sh |
|---------|----------------|-----------|
| **Propósito** | Configuración inicial completa | Actualización de código |
| **Frecuencia** | Una vez por ambiente | Cada despliegue |
| **Crea recursos** | ✅ Sí (RG, ACR, Env, App) | ❌ No |
| **Configura secretos** | ✅ Sí (interactivo) | ❌ No (usa existentes) |
| **Tiempo** | ~10 minutos | ~4 minutos |
| **Requiere input** | ✅ Sí (credenciales) | ❌ No |
| **Versiona imágenes** | ❌ No (usa `latest`) | ✅ Sí (timestamp) |

**Nota:** Los scripts tienen ligeras diferencias en nombres de recursos. Revisa y ajusta las variables en la parte superior de cada script según tu configuración:

```bash
# Variables configurables en los scripts
RESOURCE_GROUP="sika-container-rg"  # o "sika-resources"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"         # o "sikaregistry"
CONTAINER_APP_NAME="sika-assistant-text-api"  # o "sika-assistant-api"
ENVIRONMENT_NAME="sika-environment"
```

---

## 🎙️ Servicio de Voz (Voice Live API)

El servicio de voz proporciona **conversación por voz en tiempo real** usando Azure Voice Live API, permitiendo una interacción natural y fluida con el asistente de IA mediante audio.

### Características Principales

#### 🎯 Capacidades de Voz
- **Streaming de Audio Bidireccional**: Envío y recepción de audio en tiempo real
- **Formato de Audio**: PCM 16-bit, mono, 24kHz
- **Latencia Ultra-baja**: Procesamiento en tiempo real con streaming
- **Voz Neural en Español**: `es-ES-ElviraNeural` (voz femenina española)

#### 🧠 Procesamiento Inteligente
- **Azure Semantic VAD**: Detección inteligente de turnos de conversación
  - Threshold: 0.3
  - Prefix padding: 200ms
  - Silence duration: 300ms
  - End-of-utterance detection con modelo semántico
- **Deep Noise Suppression**: Reducción avanzada de ruido de fondo
- **Server Echo Cancellation**: Cancelación de eco del lado del servidor
- **Remoción de Palabras de Relleno**: Opcional (actualmente deshabilitado)

#### 📝 Transcripciones
- **Transcripción Automática del Usuario**: En tiempo real mientras habla
- **Transcripción del Agente**: Del texto generado y del audio sintetizado
- **Eventos en Tiempo Real**: Notificaciones de cuando el usuario comienza a hablar

#### 🔄 Integración con Modo Texto
- **Mismo Agente de Azure AI**: Usa el mismo `AZURE_AGENT_ID` que el modo texto
- **Contexto Compartido**: El agente mantiene coherencia entre conversaciones de texto y voz
- **Despliegue Independiente**: Servicios separados pero coordinados

### Arquitectura del Servicio de Voz

```
┌─────────────────────────────────────────────────────────────────┐
│                     Frontend (React)                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  1. Captura audio del micrófono (MediaRecorder API)      │  │
│  │  2. Convierte a PCM 16-bit, mono, 24kHz                  │  │
│  │  3. Envía bytes via WebSocket                            │  │
│  │  4. Recibe eventos JSON y bytes de audio                 │  │
│  │  5. Reproduce audio y muestra transcripciones            │  │
│  └───────────────────────────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ WSS /ws/voice
                            │ (JSON + Binary)
┌───────────────────────────▼─────────────────────────────────────┐
│          Backend Voice API (voice_websocket.py)                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  VoiceConnectionManager                                  │   │
│  │  - Gestiona sesiones de voz por usuario                 │   │
│  │  - Coordina VoiceManager para cada sesión               │   │
│  │  - Envía eventos al cliente (transcripciones, audio)    │   │
│  └────────────────────┬─────────────────────────────────────┘   │
│                       │                                          │
│  ┌────────────────────▼─────────────────────────────────────┐   │
│  │  VoiceManager (voice_manager.py)                         │   │
│  │  - Establece conexión con Azure Voice Live              │   │
│  │  - Envía audio recibido del cliente a Azure             │   │
│  │  - Procesa eventos de Azure (transcripciones, audio)    │   │
│  │  - Callbacks asíncronos para enviar al cliente          │   │
│  └────────────────────┬─────────────────────────────────────┘   │
└────────────────────────┼────────────────────────────────────────┘
                         │ WebSocket Azure
                         │ Voice Live API
┌────────────────────────▼────────────────────────────────────────┐
│              Azure Voice Live API                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  1. Recibe audio PCM del backend                         │   │
│  │  2. Aplica VAD semántico (detección de voz)             │   │
│  │  3. Transcribe audio a texto (Speech-to-Text)           │   │
│  │  4. Envía transcripción al agente de Azure AI           │   │
│  │  5. Recibe respuesta de texto del agente                │   │
│  │  6. Sintetiza voz con Neural TTS (es-ES-ElviraNeural)   │   │
│  │  7. Envía audio y transcripciones al backend            │   │
│  └──────────────────┬───────────────────────────────────────┘   │
│                     │                                            │
│  ┌──────────────────▼───────────────────────────────────────┐   │
│  │  Azure AI Agent (Mismo que modo texto)                   │   │
│  │  - Procesa mensaje transcrito                            │   │
│  │  - Genera respuesta inteligente                          │   │
│  │  - Mantiene contexto de conversación                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Componentes Principales

#### 1. `voice_websocket.py` - Servidor WebSocket

**VoiceConnectionManager**:
- Gestiona sesiones de voz por usuario
- Crea instancia de `VoiceManager` para cada sesión
- Coordina callbacks asíncronos para enviar eventos al cliente
- Maneja desconexiones y limpieza de recursos

**Endpoint `/ws/voice`**:
- Acepta conexión WebSocket
- Recibe mensajes JSON (comandos) y bytes (audio)
- Envía eventos JSON y audio binario al cliente

#### 2. `voice_manager.py` - Gestor de Audio

**VoiceManager**:
- Coordina toda la lógica de voz
- Establece conexión con Azure Voice Live API
- Procesa eventos entrantes (transcripciones, audio)
- Callbacks configurables para diferentes eventos

**AzureVoiceLive**:
- Cliente para Azure Voice Live API
- Autentica con DefaultAzureCredential
- Construye URL del WebSocket con tokens de acceso

**VoiceLiveConnection**:
- Maneja conexión WebSocket con Azure
- Cola de mensajes para recepción asíncrona
- Threads para mantener conexión activa

**AudioPlayerAsync** (opcional):
- Reproductor de audio local para testing
- Buffer en cola con streaming asíncrono
- No se usa en producción (el audio se envía al cliente)

### Variables de Entorno Adicionales

Además de las variables del servicio de texto, el servicio de voz requiere:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `AZURE_VOICELIVE_ENDPOINT` | Endpoint de Azure Voice Live | `https://eastus.api.azureml.ms` |
| `AI_FOUNDRY_AGENT_CONNECTION_STRING` | Connection string del agente | `eastus.api.azureml...` |
| `AZURE_VOICELIVE_API_VERSION` | Versión de la API | `2025-10-01` |
| `AZURE_TENANT_ID` | ID del tenant de Azure | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_CLIENT_ID` | ID del cliente (App Registration) | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_CLIENT_SECRET` | Secret del cliente | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

**Nota**: El servicio usa `DefaultAzureCredential`, que intenta autenticar en este orden:
1. Variables de entorno (Service Principal)
2. Managed Identity (en Azure)
3. Azure CLI (en desarrollo local)

### Instalación Local del Servicio de Voz

#### 1. Navegar a la carpeta de voz

```bash
cd C:\Axxon\sika-proyect\backend\voice
```

#### 2. Crear entorno virtual

```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
```

#### 3. Instalar dependencias

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**Dependencias principales**:
- `fastapi` - Framework web
- `uvicorn[standard]` - Servidor ASGI
- `websockets` - Soporte WebSocket
- `azure-ai-projects` - SDK de Azure AI
- `azure-identity` - Autenticación Azure
- `azure-ai-inference` - Inferencia de IA
- `numpy` - Procesamiento numérico de audio
- `sounddevice` - Captura y reproducción de audio (opcional)
- `websocket-client` - Cliente WebSocket para Azure

#### 4. Configurar variables de entorno

Crear archivo `.env`:

```env
# Azure AI (mismo que modo texto)
PROJECT_CONNECTION_STRING=<tu_connection_string>
AZURE_AGENT_ID=asst_<tu_agent_id>
MODEL_DEPLOYMENT_NAME=gpt-4

# Azure Voice Live
AZURE_VOICELIVE_ENDPOINT=https://eastus.api.azureml.ms
AI_FOUNDRY_AGENT_CONNECTION_STRING=<agent_connection_string>
AZURE_VOICELIVE_API_VERSION=2025-10-01

# Service Principal (para autenticación local)
AZURE_TENANT_ID=<tu_tenant_id>
AZURE_CLIENT_ID=<tu_client_id>
AZURE_CLIENT_SECRET=<tu_client_secret>

# Configuración del servidor
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
HOST=0.0.0.0
PORT=8001
ENVIRONMENT=development
```

#### 5. Ejecutar el servidor

```bash
python voice_websocket.py
```

**Salida esperada**:
```
============================================================
🎤 SIKA AI Voice Assistant API
============================================================
📍 URL: http://localhost:8001
🔌 WebSocket: ws://localhost:8001/ws/voice
📊 Health: http://localhost:8001/health
============================================================
🤖 Agent ID: asst_xxxxxxxxxxxxx
🎙️ Voice Live API enabled
============================================================
```

### Protocolo WebSocket de Voz

#### Mensajes Cliente → Servidor

##### 1. Inicialización de Sesión
```json
{
  "type": "init_voice",
  "user_id": "user_12345"
}
```

**Respuesta**:
```json
{
  "type": "voice_session_ready",
  "session_id": "session_abc123"
}
```

##### 2. Envío de Audio
- **Formato**: Datos binarios (no JSON)
- **Encoding**: PCM 16-bit, mono, 24kHz
- **Método**: `websocket.send_bytes(audio_data)`

##### 3. Detener Sesión
```json
{
  "type": "stop_voice"
}
```

**Respuesta**:
```json
{
  "type": "voice_session_stopped"
}
```

#### Mensajes Servidor → Cliente

##### 1. Sesión Lista
```json
{
  "type": "voice_session_ready",
  "session_id": "session_abc123"
}
```

##### 2. Transcripción del Usuario
```json
{
  "type": "user_transcript",
  "text": "¿Qué es Sikalastic-560?"
}
```

##### 3. Respuesta de Texto del Agente
```json
{
  "type": "agent_text",
  "text": "Sikalastic-560 es un sellador elástico..."
}
```

##### 4. Transcripción de Audio del Agente
```json
{
  "type": "agent_transcript",
  "text": "Sikalastic-560 es un sellador elástico..."
}
```

##### 5. Audio del Agente
- **Formato**: Datos binarios (no JSON)
- **Encoding**: PCM 16-bit, mono, 24kHz
- **Método**: Cliente recibe con `websocket.receive_bytes()`
- **Acción**: Cliente debe reproducir el audio

##### 6. Error
```json
{
  "type": "error",
  "message": "Error description"
}
```

### Ejemplo de Cliente JavaScript

```javascript
// Conectar al WebSocket de voz
const wsVoice = new WebSocket('ws://localhost:8001/ws/voice');

// 1. Inicializar sesión al conectar
wsVoice.onopen = () => {
  console.log('Conectado a Voice API');
  wsVoice.send(JSON.stringify({
    type: 'init_voice',
    user_id: 'user_' + Date.now()
  }));
};

// 2. Manejar mensajes del servidor
wsVoice.onmessage = async (event) => {
  // Verificar si es JSON o binario
  if (event.data instanceof Blob) {
    // Audio del agente - reproducir
    const audioData = await event.data.arrayBuffer();
    playAudio(audioData);
  } else {
    // Mensaje JSON
    const data = JSON.parse(event.data);

    switch(data.type) {
      case 'voice_session_ready':
        console.log('Sesión de voz lista:', data.session_id);
        startRecording(); // Iniciar captura de micrófono
        break;

      case 'user_transcript':
        console.log('Usuario:', data.text);
        displayUserTranscript(data.text);
        break;

      case 'agent_text':
        console.log('Agente (texto):', data.text);
        break;

      case 'agent_transcript':
        console.log('Agente (audio):', data.text);
        displayAgentTranscript(data.text);
        break;

      case 'error':
        console.error('Error:', data.message);
        break;
    }
  }
};

// 3. Capturar y enviar audio del micrófono
let mediaRecorder;
let audioContext;

async function startRecording() {
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      sampleRate: 24000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true
    }
  });

  audioContext = new AudioContext({ sampleRate: 24000 });
  const source = audioContext.createMediaStreamSource(stream);
  const processor = audioContext.createScriptProcessor(4096, 1, 1);

  processor.onaudioprocess = (e) => {
    const inputData = e.inputBuffer.getChannelData(0);

    // Convertir float32 a PCM 16-bit
    const pcmData = new Int16Array(inputData.length);
    for (let i = 0; i < inputData.length; i++) {
      const s = Math.max(-1, Math.min(1, inputData[i]));
      pcmData[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
    }

    // Enviar audio al servidor
    if (wsVoice.readyState === WebSocket.OPEN) {
      wsVoice.send(pcmData.buffer);
    }
  };

  source.connect(processor);
  processor.connect(audioContext.destination);
}

// 4. Reproducir audio recibido
function playAudio(audioData) {
  const audioBuffer = audioContext.createBuffer(1, audioData.byteLength / 2, 24000);
  const channelData = audioBuffer.getChannelData(0);
  const pcmData = new Int16Array(audioData);

  for (let i = 0; i < pcmData.length; i++) {
    channelData[i] = pcmData[i] / 32768.0;
  }

  const source = audioContext.createBufferSource();
  source.buffer = audioBuffer;
  source.connect(audioContext.destination);
  source.start();
}

// 5. Detener sesión de voz
function stopVoiceSession() {
  wsVoice.send(JSON.stringify({
    type: 'stop_voice'
  }));
}
```

### Despliegue en Azure del Servicio de Voz

El despliegue del servicio de voz es similar al de texto, pero con configuración específica para audio.

#### Variables Configurables

```bash
# En azure-setup.sh y deploy.sh
RESOURCE_GROUP="sika-container-rg"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-voice-api"  # ⚠️ Nombre diferente
ENVIRONMENT_NAME="sika-environment"
IMAGE_NAME="sika-assistant-voice"  # ⚠️ Imagen diferente
```

#### Setup Inicial (azure-setup.sh)

```bash
cd C:\Axxon\sika-proyect\backend\voice

# En Git Bash
chmod +x azure-setup.sh
chmod +x deploy.sh

# Autenticar en Azure
az login

# Ejecutar setup
./azure-setup.sh
```

**Durante la ejecución se solicitará**:
- `PROJECT_CONNECTION_STRING`
- `AZURE_AGENT_ID`
- `FRONTEND_URL`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

**Tiempo estimado**: 8-12 minutos

#### Despliegue Continuo (deploy.sh)

```bash
cd C:\Axxon\sika-proyect\backend\voice

# Ejecutar despliegue
./deploy.sh
```

**Tiempo estimado**: 3-5 minutos

**URL del servicio**:
```
API: https://sika-assistant-voice-api.xxx.eastus.azurecontainerapps.io
WebSocket: wss://sika-assistant-voice-api.xxx.eastus.azurecontainerapps.io/ws/voice
Health: https://sika-assistant-voice-api.xxx.eastus.azurecontainerapps.io/health
```

### Dockerfile - Configuración Específica de Voz

El Dockerfile del servicio de voz incluye dependencias adicionales para procesamiento de audio:

```dockerfile
# Instalar dependencias del sistema para audio
RUN apt-get update && apt-get install -y \
    libportaudio2 \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*
```

**Diferencias con el servicio de texto**:
- **Puerto**: 8001 (en vez de 8000)
- **Dependencias de sistema**: libportaudio2, libsndfile1
- **Health check**: apunta a puerto 8001
- **Archivos copiados**: `voice_websocket.py`, `voice_manager.py`

### Monitoreo del Servicio de Voz

```bash
# Ver logs en tiempo real
az containerapp logs show \
  --name sika-assistant-voice-api \
  --resource-group sika-container-rg \
  --follow

# Estado del servicio
az containerapp show \
  --name sika-assistant-voice-api \
  --resource-group sika-container-rg \
  --query "properties.runningStatus"

# Health check
curl https://sika-assistant-voice-api.xxx.eastus.azurecontainerapps.io/health
```

### Troubleshooting del Servicio de Voz

#### Error: "Azure Voice Live authentication failed"

**Solución**:
```bash
# Verificar variables de entorno
echo $AZURE_TENANT_ID
echo $AZURE_CLIENT_ID
echo $AZURE_CLIENT_SECRET

# Verificar que el Service Principal tiene permisos
az role assignment list --assignee $AZURE_CLIENT_ID

# Re-autenticar
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

#### Error: "WebSocket connection failed"

**Solución**:
```bash
# Verificar que el endpoint es correcto
echo $AZURE_VOICELIVE_ENDPOINT

# Debe ser formato: https://eastus.api.azureml.ms
# NO debe incluir /voice-live/realtime

# Verificar conexión
curl -I $AZURE_VOICELIVE_ENDPOINT
```

#### Error: "Audio not playing on client"

**Causas comunes**:
1. **Formato de audio incorrecto**: Debe ser PCM 16-bit, mono, 24kHz
2. **AudioContext no inicializado**: Requiere interacción del usuario
3. **Datos binarios malformados**: Verificar que se reciben como Blob

**Solución**:
```javascript
// Inicializar AudioContext después de click del usuario
button.addEventListener('click', async () => {
  audioContext = new AudioContext({ sampleRate: 24000 });
  // ... resto del código
});
```

#### Sesión de voz se interrumpe frecuentemente

**Causas**:
- VAD threshold muy sensible
- Ruido de fondo alto
- Latencia de red

**Solución**: Ajustar parámetros en `voice_manager.py`:
```python
"turn_detection": {
    "type": "azure_semantic_vad",
    "threshold": 0.5,  # Aumentar de 0.3 a 0.5
    "silence_duration_ms": 500,  # Aumentar de 300 a 500
}
```

### Comparación: Texto vs Voz

| Característica | Servicio Texto | Servicio Voz |
|----------------|----------------|--------------|
| **Puerto** | 8000 | 8001 |
| **Endpoint** | `/ws/chat` | `/ws/voice` |
| **Formato datos** | JSON | JSON + Binary (PCM) |
| **Latencia** | ~500ms | ~200ms (streaming) |
| **Ancho de banda** | ~10 KB/s | ~50-100 KB/s |
| **Procesamiento** | Texto directo | STT + TTS + Audio |
| **Experiencia** | Chat escrito | Conversación natural |
| **Uso recomendado** | Consultas detalladas | Interacción rápida |

### Costos Adicionales - Servicio de Voz

| Componente | Costo Estimado |
|------------|----------------|
| Azure Voice Live API | ~$0.015 por minuto de conversación |
| Speech-to-Text (STT) | ~$0.012 por minuto |
| Neural TTS | ~$0.016 por 1M caracteres |
| Container App adicional | ~$35-40/mes (réplica adicional) |
| Datos transferidos | ~3-5 MB por minuto de voz |

**Estimación mensual** (100 horas de conversación):
- Voice Live: ~$90
- Container App: ~$40
- Total adicional: **~$130/mes**

---

## Estructura del Proyecto

```
C:\Axxon\sika-proyect\
│
├── README.md                          # Este archivo (documentación principal)
│
├── frontend\                          # 🎨 Frontend React + Vite
│   │
│   ├── src/
│   │   ├── components/
│   │   │   ├── ChatInterface.jsx     # 📱 Componente principal del chat
│   │   │   └── ChatInterface.css     # 🎨 Estilos del chat
│   │   ├── App.jsx                   # 🚀 Componente raíz
│   │   ├── App.css                   # 🎨 Estilos globales
│   │   ├── main.jsx                  # 🔧 Entry point
│   │   └── index.css                 # 🎨 Estilos base
│   │
│   ├── public/                       # 📁 Assets estáticos
│   ├── dist/                         # 📦 Build de producción
│   │
│   ├── .env.development              # 🔧 Variables de desarrollo
│   ├── .env.production               # 🌐 Variables de producción
│   ├── package.json                  # 📦 Dependencias npm
│   ├── vite.config.js                # ⚙️ Config de Vite
│   │
│   ├── Dockerfile                    # 🐳 Multi-stage build (Node + Nginx)
│   ├── nginx.conf                    # 🌐 Config de Nginx
│   ├── .dockerignore                 # 🚫 Exclusiones Docker
│   │
│   ├── azure-setup-fixed.sh          # 🏗️ Setup inicial en Azure
│   ├── deploy.sh                     # 🚢 Deployment continuo
│   ├── logs.sh                       # 📋 Ver logs de Azure
│   ├── DEPLOYMENT.md                 # 📚 Guía de deployment
│   └── test_websocket.html           # 🧪 Cliente de prueba
│
└── backend\
    │
    ├── text\                          # 💬 API de Texto (Chat WebSocket)
    │   │
    │   ├── assistant_websocket.py     # 🚀 Aplicación FastAPI principal (484 líneas)
    │   │                              #    - Define endpoints REST y WebSocket
    │   │                              #    - Clase PersistentChatManager
    │   │                              #    - Gestión de sesiones y conexiones
    │   │
    │   ├── azure-setup.sh             # 🏗️ Script de configuración inicial Azure
    │   ├── deploy.sh                  # 🚢 Script de despliegue continuo
    │   │
    │   ├── Dockerfile                 # 🐳 Configuración de contenedor Docker
    │   │                              #    - Base: python:3.11-slim
    │   │                              #    - Non-root user: appuser
    │   │                              #    - Puerto expuesto: 8000
    │   │
    │   ├── requirements.txt           # 📦 Dependencias Python del proyecto
    │   ├── .env.example               # 📝 Plantilla de variables de entorno
    │   ├── .env                       # 🔐 Config local (NO en git)
    │   ├── .dockerignore              # 🚫 Exclusiones para Docker build
    │   │
    │   ├── AZURE_DEPLOYMENT.md        # 📚 Guía detallada de despliegue Azure
    │   ├── test_websocket.html        # 🧪 Cliente de pruebas WebSocket
    │   └── README.md                  # 📄 Documentación específica del backend
    │
    ├── voice\                         # 🎙️ API de Voz (Voice Live WebSocket)
    │   │
    │   ├── voice_websocket.py         # 🚀 Aplicación FastAPI para voz (345 líneas)
    │   │                              #    - Endpoint WebSocket /ws/voice
    │   │                              #    - Clase VoiceConnectionManager
    │   │                              #    - Integración con Azure Voice Live
    │   │
    │   ├── voice_manager.py           # 🎧 Gestor de audio y voz (493 líneas)
    │   │                              #    - VoiceManager: Coordinación principal
    │   │                              #    - AzureVoiceLive: Cliente Voice Live API
    │   │                              #    - VoiceLiveConnection: WebSocket Azure
    │   │                              #    - AudioPlayerAsync: Reproductor asíncrono
    │   │
    │   ├── azure-setup.sh             # 🏗️ Script de configuración inicial Azure
    │   ├── deploy.sh                  # 🚢 Script de despliegue continuo
    │   │
    │   ├── Dockerfile                 # 🐳 Configuración de contenedor Docker
    │   │                              #    - Base: python:3.11-slim
    │   │                              #    - Dependencias de audio (libportaudio2)
    │   │                              #    - Non-root user: appuser
    │   │                              #    - Puerto expuesto: 8001
    │   │
    │   ├── requirements.txt           # 📦 Dependencias: FastAPI, Azure AI, numpy, sounddevice
    │   ├── .env                       # 🔐 Config local (NO en git)
    │   └── test_websocket.html        # 🧪 Cliente de pruebas de voz
    │
    ├── requirements.txt               # 📦 Dependencias del backend general
    ├── setup.py                       # 🔧 Configuración de paquete Python
    └── .venv\                         # 🐍 Entorno virtual de Python
```

---

## Variables de Entorno

### Variables Requeridas

| Variable | Descripción | Ejemplo | ¿Dónde obtenerla? |
|----------|-------------|---------|-------------------|
| `PROJECT_CONNECTION_STRING` | Connection string de Azure AI Project | `eastus.api.azureml...` | Azure AI Studio → Project Settings |
| `AZURE_AGENT_ID` | ID del agente de Azure AI | `asst_abc123xyz` | Azure AI Studio → Agents → Tu agente |
| `MODEL_DEPLOYMENT_NAME` | Nombre del modelo GPT | `gpt-4` | Azure AI Studio → Deployments |
| `ALLOWED_ORIGINS` | Orígenes permitidos para CORS | `https://app.com,https://app2.com` | URL de tu frontend |

### Variables Opcionales

| Variable | Por Defecto | Descripción |
|----------|-------------|-------------|
| `HOST` | `0.0.0.0` | Host para bind del servidor |
| `PORT` | `8000` | Puerto de la aplicación |
| `ENVIRONMENT` | `development` | Ambiente (development/production) |
| `AZURE_TENANT_ID` | - | ID del tenant (para Service Principal) |
| `AZURE_CLIENT_ID` | - | ID del cliente (para Service Principal) |
| `AZURE_CLIENT_SECRET` | - | Secret del cliente (para Service Principal) |

### Configuración por Ambiente

**Desarrollo Local (`.env`):**
```env
PROJECT_CONNECTION_STRING=eastus.api.azureml.ms;...
AZURE_AGENT_ID=asst_abc123
MODEL_DEPLOYMENT_NAME=gpt-4
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
HOST=0.0.0.0
PORT=8000
ENVIRONMENT=development
```

**Producción Azure (Container App Secrets):**
```bash
# Los secretos se configuran en azure-setup.sh automáticamente
# Y se referencian como: secretref:nombre-secreto

# Variables configuradas:
PROJECT_CONNECTION_STRING: secretref:azure-connection-string
AZURE_AGENT_ID: secretref:azure-agent-id
MODEL_DEPLOYMENT_NAME: gpt-4
ENVIRONMENT: production
ALLOWED_ORIGINS: secretref:frontend-url
```

---

## API y Endpoints

### REST Endpoints

#### `GET /`
**Descripción:** Información del servicio y estado
**Respuesta:**
```json
{
  "message": "SIKA AI Assistant WebSocket API is running",
  "version": "1.0.0",
  "endpoints": {
    "health": "/health",
    "stats": "/api/stats",
    "websocket": "/ws/chat",
    "docs": "/docs"
  }
}
```

#### `GET /health`
**Descripción:** Health check para Azure Container Apps
**Uso:** Azure lo llama automáticamente para verificar disponibilidad
**Respuesta:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-03T14:30:00Z"
}
```

#### `GET /api/stats`
**Descripción:** Estadísticas del sistema
**Respuesta:**
```json
{
  "active_connections": 5,
  "total_threads": 12,
  "environment": "production"
}
```

#### `GET /docs`
**Descripción:** Documentación interactiva Swagger UI
**Uso:** Explorar y probar endpoints REST desde navegador

### WebSocket Endpoint

#### `WS /ws/chat`
**Descripción:** Conexión WebSocket para chat en tiempo real
**URL:** `ws://localhost:8000/ws/chat` (local) o `wss://tu-app.azurecontainerapps.io/ws/chat` (Azure)

Ver sección [Protocolo WebSocket](#protocolo-websocket) para detalles completos.

---

## Protocolo WebSocket

### Tipos de Mensajes

#### Cliente → Servidor

##### 1. Inicialización
```json
{
  "type": "init",
  "user_id": "user_12345"
}
```
**Descripción:** Inicializa o recupera sesión del usuario
**Respuesta:** `session_ready`

##### 2. Enviar Mensaje
```json
{
  "type": "message",
  "message": "¿Qué es Sikalastic-560?"
}
```
**Descripción:** Envía mensaje al asistente
**Respuesta:** `processing` → `bot_message`

##### 3. Limpiar Sesión
```json
{
  "type": "clear_session"
}
```
**Descripción:** Elimina permanentemente el historial de conversación
**Respuesta:** `session_cleared`

##### 4. Obtener Estadísticas
```json
{
  "type": "get_stats"
}
```
**Descripción:** Obtiene estadísticas del sistema
**Respuesta:** `stats`

#### Servidor → Cliente

##### 1. Sesión Lista
```json
{
  "type": "session_ready",
  "message": "Session ready for user user_12345",
  "thread_id": "thread_abc123xyz",
  "is_new_session": true
}
```

##### 2. Procesando
```json
{
  "type": "processing",
  "message": "Processing your request..."
}
```

##### 3. Respuesta del Bot
```json
{
  "type": "bot_message",
  "message": "Sikalastic-560 es un sellador elástico de poliuretano...",
  "status": "success"
}
```

##### 4. Sesión Limpiada
```json
{
  "type": "session_cleared",
  "message": "Your conversation history has been permanently deleted"
}
```

##### 5. Estadísticas
```json
{
  "type": "stats",
  "active_connections": 3,
  "total_threads": 8
}
```

##### 6. Error
```json
{
  "type": "error",
  "message": "Error description here",
  "status": "error"
}
```

### Ejemplo de Flujo Completo

```javascript
// Conectar al WebSocket
const ws = new WebSocket('wss://tu-app.azurecontainerapps.io/ws/chat');

// 1. Inicializar sesión al conectar
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'init',
    user_id: 'user_' + Date.now()
  }));
};

// 2. Recibir mensajes del servidor
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  switch(data.type) {
    case 'session_ready':
      console.log('Sesión iniciada:', data.thread_id);
      // Ahora puedes enviar mensajes
      break;

    case 'processing':
      console.log('Procesando...');
      break;

    case 'bot_message':
      console.log('Respuesta:', data.message);
      break;

    case 'error':
      console.error('Error:', data.message);
      break;
  }
};

// 3. Enviar mensaje al asistente
function sendMessage(text) {
  ws.send(JSON.stringify({
    type: 'message',
    message: text
  }));
}

// 4. Limpiar historial de conversación
function clearHistory() {
  ws.send(JSON.stringify({
    type: 'clear_session'
  }));
}
```

---

## Testing

### Probar Localmente

#### Opción 1: Cliente HTML (Recomendado)

1. Ejecutar el servidor:
   ```bash
   python assistant_websocket.py
   ```

2. Abrir `test_websocket.html` en el navegador

3. Características del cliente de prueba:
   - Conectar/desconectar WebSocket
   - Enviar mensajes y recibir respuestas
   - Limpiar sesión de conversación
   - Ver estadísticas del sistema
   - Historial visual de mensajes

#### Opción 2: cURL para REST API

```bash
# Health check
curl http://localhost:8000/health

# Estadísticas
curl http://localhost:8000/api/stats

# Información del servicio
curl http://localhost:8000/
```

#### Opción 3: Postman/Insomnia (WebSocket)

1. Crear nueva conexión WebSocket
2. URL: `ws://localhost:8000/ws/chat`
3. Conectar y enviar mensaje init:
   ```json
   {"type": "init", "user_id": "test_user"}
   ```

### Probar en Azure

Reemplazar `localhost:8000` con tu URL de Azure:

```bash
# Health check
curl https://tu-app.azurecontainerapps.io/health

# Documentación
https://tu-app.azurecontainerapps.io/docs

# WebSocket (desde test_websocket.html)
wss://tu-app.azurecontainerapps.io/ws/chat
```

---

## Monitoreo y Logs

### Ver Logs en Azure

**Logs en tiempo real:**
```bash
az containerapp logs show \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg \
  --follow
```

**Logs de los últimos 15 minutos:**
```bash
az containerapp logs show \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg \
  --tail 100
```

### Monitorear Aplicación

**Estado de la aplicación:**
```bash
az containerapp show \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg \
  --query "properties.runningStatus" \
  --output tsv
```

**Ver réplicas activas:**
```bash
az containerapp revision list \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg \
  --query "[].{Name:name, Active:properties.active, Replicas:properties.replicas}" \
  --output table
```

### Azure Portal

1. Ir a [Azure Portal](https://portal.azure.com)
2. Buscar "sika-assistant-text-api"
3. Ver:
   - **Overview**: Estado, URL, réplicas
   - **Metrics**: CPU, memoria, requests
   - **Log stream**: Logs en vivo
   - **Application Insights**: Métricas avanzadas (si está configurado)

---

## Seguridad

### Implementado

- **Variables de entorno**: No hay credenciales hardcoded en el código
- **Azure Key Vault**: Secretos almacenados en Container App Secrets
- **CORS**: Restricción de orígenes permitidos
- **HTTPS/WSS**: Certificados SSL automáticos en Azure
- **Non-root Docker**: Contenedor corre con usuario `appuser` (no root)
- **DefaultAzureCredential**: Soporte para Managed Identity

### Recomendaciones Adicionales

#### 1. Implementar Autenticación
```python
# Agregar middleware de JWT en assistant_websocket.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # Validar JWT token
    pass
```

#### 2. Rate Limiting
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.websocket("/ws/chat")
@limiter.limit("10/minute")
async def websocket_endpoint(...):
    pass
```

#### 3. Input Validation
```python
from pydantic import BaseModel, Field

class MessageRequest(BaseModel):
    message: str = Field(..., max_length=2000)
```

#### 4. Secrets Management
- Rotar secretos regularmente (cada 90 días)
- Usar Azure Key Vault para secretos críticos
- No compartir `.env` en repositorios

#### 5. Network Security
```bash
# Restringir acceso a Azure AI Services por IP
az cognitiveservices account network-rule add \
  --name tu-ai-service \
  --resource-group tu-rg \
  --ip-address tu-ip-publica
```

---

## Troubleshooting

### Error: "Cannot connect to WebSocket"

**Problema:** Cliente no puede conectar a `/ws/chat`

**Soluciones:**
```bash
# 1. Verificar que el servidor está corriendo
curl http://localhost:8000/health

# 2. Verificar que no haya firewall bloqueando puerto 8000
netstat -ano | findstr :8000

# 3. Verificar CORS en .env
ALLOWED_ORIGINS=http://localhost:5173

# 4. Revisar logs del servidor
# Buscar mensajes tipo: "WebSocket connection opened"
```

### Error: "Azure authentication failed"

**Problema:** No puede autenticar con Azure

**Soluciones:**
```bash
# 1. Login en Azure CLI
az login

# 2. Verificar suscripción activa
az account show

# 3. Verificar credenciales en .env
# Asegurarse de que PROJECT_CONNECTION_STRING es correcto

# 4. Probar autenticación manualmente
az account get-access-token --resource https://management.azure.com/
```

### Error: "Thread not found" o "Agent not responding"

**Problema:** Azure AI no responde correctamente

**Soluciones:**
1. Verificar que `AZURE_AGENT_ID` es correcto en `.env`
2. Verificar que el agente está activo en Azure AI Studio
3. Verificar cuota de tokens no excedida
4. Revisar logs de Azure AI en Azure Portal

### Error: "Container App won't start"

**Problema:** Container App en estado "Failed" o "Provisioning"

**Soluciones:**
```bash
# 1. Ver logs detallados
az containerapp logs show \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg

# 2. Verificar health check
curl https://tu-app.azurecontainerapps.io/health

# 3. Verificar secrets configurados
az containerapp secret list \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg

# 4. Reiniciar la app
az containerapp restart \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg
```

### Problemas con Scripts .sh en Windows

**Problema:** Scripts no se ejecutan o dan errores de sintaxis

**Soluciones:**

```bash
# 1. Usar Git Bash en lugar de CMD/PowerShell
# Descargar de: https://git-scm.com/downloads

# 2. Verificar formato de línea (debe ser LF, no CRLF)
dos2unix azure-setup.sh deploy.sh

# O en Git Bash:
sed -i 's/\r$//' azure-setup.sh
sed -i 's/\r$//' deploy.sh

# 3. Dar permisos de ejecución
chmod +x azure-setup.sh deploy.sh

# 4. Ejecutar con bash explícitamente
bash azure-setup.sh
```

### Sesiones no persisten después de reinicio

**Problema:** Conversaciones se pierden al reiniciar servidor

**Explicación:** Esto es normal. Las sesiones se almacenan en memoria (diccionario Python). El historial de conversación sí persiste en Azure AI Threads y se recupera automáticamente cuando el usuario se reconecta.

**Solución futura:** Implementar Redis para sesiones distribuidas:
```bash
# Agregar a requirements.txt
redis==4.5.4
```

---

## Costos Estimados

### Costos Mensuales en Azure

#### Servicio de Texto (Chat)

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Azure Container Apps (Texto)** | 1 réplica 24/7, 0.5vCPU, 1GB RAM | ~$35-40/mes |
| **Azure Container Registry** | Basic tier (compartido) | ~$5/mes |
| **Azure AI Services (GPT-4)** | Pay-per-token | Variable* |
| **Egress Data Transfer** | Primeros 100GB gratis | $0-10/mes |
| **Total Servicio Texto** | Sin tokens AI | ~$40-50/mes |

*Costos de Azure AI:
- GPT-4: ~$0.03 por 1K tokens input, ~$0.06 por 1K output
- Ejemplo: 10,000 mensajes/mes (avg 500 tokens) = ~$300-500/mes

#### Servicio de Voz (Voice Live)

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Azure Container Apps (Voz)** | 1 réplica 24/7, 0.5vCPU, 1GB RAM | ~$35-40/mes |
| **Azure Voice Live API** | Pay-per-minute | ~$0.015/minuto |
| **Speech-to-Text (incluido)** | Parte de Voice Live | ~$0.012/minuto |
| **Neural TTS (incluido)** | Parte de Voice Live | ~$0.016/1M caracteres |
| **Egress Data Transfer** | Audio streaming | ~$5-10/mes |
| **Total Servicio Voz** | 100 horas/mes | ~$130/mes |

#### Servicio Frontend (React + Vite)

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Azure Container Apps (Frontend)** | 0.25vCPU, 0.5GB RAM, 1-5 réplicas | ~$15-25/mes |
| **Azure Container Registry** | Basic tier (compartido con backends) | Incluido |
| **Egress Data Transfer** | Archivos estáticos | ~$2-5/mes |
| **Total Servicio Frontend** | Hosting completo | ~$20-30/mes |

#### Costo Total (Todos los Servicios)

| Concepto | Costo Mensual |
|----------|---------------|
| Infraestructura Backend (texto + voz) | ~$80-90/mes |
| Infraestructura Frontend (React app) | ~$20-30/mes |
| Azure AI (GPT-4, 10K mensajes) | ~$300-500/mes |
| Voice Live (100 horas voz) | ~$90/mes |
| **Total Estimado (Sistema Completo)** | **~$490-710/mes** |

**Notas**:
- Los costos de Voice Live se cobran por minuto de conversación activa
- El uso del mismo agente de IA compartido entre texto y voz optimiza costos
- Container Registry es compartido entre todos los servicios (frontend + backends)
- El frontend puede escalar a 0 réplicas en inactividad para reducir costos

### Optimización de Costos

#### Para el Servicio de Texto:

```bash
# 1. Reducir réplicas mínimas (escala a 0 en inactividad)
az containerapp update \
  --name sika-assistant-text-api \
  --resource-group sika-container-rg \
  --min-replicas 0 \
  --max-replicas 2

# 2. Usar modelo más económico
MODEL_DEPLOYMENT_NAME=gpt-3.5-turbo  # En vez de gpt-4

# 3. Implementar caché de respuestas frecuentes
# 4. Limitar longitud de mensajes
# 5. Usar tier "Consumption" de Container Apps (pay-per-execution)
```

#### Para el Servicio de Voz:

```bash
# 1. Escalar a 0 réplicas cuando no se use
az containerapp update \
  --name sika-assistant-voice-api \
  --resource-group sika-container-rg \
  --min-replicas 0 \
  --max-replicas 1

# 2. Ajustar VAD para reducir tiempo de procesamiento
# En voice_manager.py, aumentar silence_duration_ms para terminar conversaciones más rápido

# 3. Implementar timeout de sesiones inactivas
# Cerrar automáticamente sesiones sin actividad después de 2-3 minutos

# 4. Usar voz estándar en vez de neural (si es aceptable)
# En voice_manager.py: "type": "azure-standard" → más económico

# 5. Limitar duración máxima de sesiones de voz
# Implementar límite de 10-15 minutos por sesión
```

#### Para el Frontend:

```bash
# 1. Escalar a 0 réplicas cuando no se use (ideal para demos o pruebas)
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --min-replicas 0 \
  --max-replicas 3

# 2. Reducir recursos si no hay mucho tráfico
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --cpu 0.25 \
  --memory 0.5Gi

# 3. Habilitar CDN para reducir egress costs
# Configurar Azure CDN delante del Container App para cachear archivos estáticos

# 4. Optimizar bundle size
# En frontend: npm run build --mode production
# Minimiza JS/CSS y elimina código no usado

# 5. Usar tier "Consumption" de Container Apps
# Pay-per-execution en vez de dedicated instances
```

#### Estrategias Generales:

- **Usar ambiente compartido**: Todos los servicios (frontend + backends) comparten el mismo Container App Environment y ACR
- **Monitorear uso**: Revisar logs para identificar picos de uso innecesario
- **Implementar rate limiting**: Evitar abuso del servicio
- **Caché de respuestas**: Para preguntas frecuentes, especialmente en modo texto
- **Horarios de operación**: Si es viable, apagar servicios fuera de horario laboral

---

## Contribuir

### Guía para Contribuciones

1. **Fork** el repositorio
2. Crear **rama de feature**: `git checkout -b feature/nueva-caracteristica`
3. **Commit** cambios: `git commit -m 'Add: nueva característica'`
4. **Push** a la rama: `git push origin feature/nueva-caracteristica`
5. Abrir **Pull Request**

### Estándares de Código

- Usar **type hints** en Python
- Documentar funciones con **docstrings**
- Seguir **PEP 8** style guide
- Agregar **tests** para nuevas features
- Actualizar **README.md** si es necesario

### Testing Antes de PR

```bash
# Ejecutar localmente
python assistant_websocket.py

# Probar con test_websocket.html
# Verificar que health check funciona
curl http://localhost:8000/health

# (Futuro) Ejecutar tests unitarios
pytest tests/
```

---

## Licencia

Este proyecto es propiedad de **Axxon** y **Sika**.
Todos los derechos reservados.

**Autor:** rsanchez
**Versión:** 2.1.0
**Última actualización:** Noviembre 2025

**Changelog v2.1.0:**
- ✅ Frontend completo en React 18.3 + Vite 6.0
- ✅ Interfaz web moderna con modo texto y modo voz
- ✅ Web Audio API para reproducción de audio en tiempo real
- ✅ Indicadores visuales de procesamiento y estado de conexión
- ✅ Diseño responsive optimizado para desktop y mobile
- ✅ Deployment automatizado a Azure Container Apps
- ✅ Sistema completo: frontend + 2 backends (texto + voz)
- ✅ Documentación completa de deployment del frontend

**Changelog v2.0.0:**
- ✅ Añadido servicio de voz con Azure Voice Live API
- ✅ Conversación por voz en tiempo real con streaming de audio
- ✅ Transcripciones automáticas de usuario y agente
- ✅ Detección semántica de voz (VAD) con cancelación de eco y ruido
- ✅ Voz neural en español (es-ES-ElviraNeural)
- ✅ Arquitectura dual: texto (puerto 8000) y voz (puerto 8001)
- ✅ Documentación completa de ambos backends

---

## Contacto y Soporte

### Recursos Adicionales

#### Documentación
- **Backend Texto**: Ver `backend/text/AZURE_DEPLOYMENT.md`
- **Backend Voz**: Ver sección [🎙️ Servicio de Voz](#️-servicio-de-voz-voice-live-api)
- **Azure Container Apps**: [Documentación oficial](https://learn.microsoft.com/azure/container-apps/)
- **Azure AI Studio**: [Portal](https://ai.azure.com)
- **Azure Voice Live API**: [Documentación](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live-api)
- **FastAPI**: [Documentación](https://fastapi.tiangolo.com/)

#### Servicios Desplegados
- **Servicio de Texto (Chat)**: Puerto 8000, WebSocket `/ws/chat`
- **Servicio de Voz (Voice Live)**: Puerto 8001, WebSocket `/ws/voice`

### Reportar Problemas

Si encuentras problemas o bugs:
1. Revisar sección [Troubleshooting](#troubleshooting) para servicio de texto
2. Revisar sección [Troubleshooting del Servicio de Voz](#troubleshooting-del-servicio-de-voz) para servicio de voz
3. Verificar logs en Azure para el servicio correspondiente
4. Contactar al equipo de desarrollo

---

**¡Gracias por usar SIKA AI Assistant! 🚀💬🎙️**
