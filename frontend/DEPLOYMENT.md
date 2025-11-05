# 🚀 Deployment del Frontend a Azure Container Apps

Guía completa para desplegar el frontend de SIKA AI Assistant en Azure.

## 📋 Requisitos Previos

1. **Azure CLI instalado**
   ```bash
   az --version
   ```

2. **Docker instalado**
   ```bash
   docker --version
   ```

3. **Login en Azure**
   ```bash
   az login
   ```

4. **Backends ya desplegados**
   - Text API: `wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat`
   - Voice API: `wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice`

---

## 🎬 Primer Deployment (Setup Inicial)

### 1. Configurar las URLs de los backends

Edita `azure-setup-fixed.sh` (líneas 27-28) con las URLs correctas:

```bash
BACKEND_TEXT_URL="wss://tu-text-api.azurecontainerapps.io/ws/chat"
BACKEND_VOICE_URL="wss://tu-voice-api.azurecontainerapps.io/ws/voice"
```

### 2. Ejecutar el setup inicial

```bash
cd frontend
chmod +x azure-setup-fixed.sh
./azure-setup-fixed.sh
```

Esto creará:
- ✅ Resource Group (si no existe)
- ✅ Azure Container Registry (ACR)
- ✅ Container App Environment
- ✅ Container App del frontend
- ✅ Build y push de la imagen inicial

### 3. Verificar el deployment

Al finalizar, el script te mostrará la URL:
```
🌐 URL de tu frontend:
  App: https://sika-assistant-frontend-app.XXXXXX.eastus.azurecontainerapps.io
```

Abre esa URL en tu navegador y verifica que:
- ✅ La página carga correctamente
- ✅ El status muestra "Conectado"
- ✅ Modo texto funciona
- ✅ Modo voz funciona

---

## 🔄 Deployments Posteriores (Actualizaciones)

### Cuando hagas cambios en el código:

```bash
cd frontend
chmod +x deploy.sh
./deploy.sh
```

El script automáticamente:
1. 🏗️ Construye la nueva imagen con las URLs de backend
2. 🏷️ Etiqueta con timestamp (ej: `v20251105-143022`)
3. 📤 Sube a Azure Container Registry
4. 🔄 Actualiza el Container App
5. ✅ Te muestra la URL final

### Versionado automático

Cada deployment crea una nueva versión:
- `sika-assistant-frontend:v20251105-143022` (versión específica)
- `sika-assistant-frontend:latest` (última versión)

---

## 📋 Ver Logs en Tiempo Real

```bash
chmod +x logs.sh
./logs.sh
```

O manualmente:
```bash
az containerapp logs show \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --follow
```

---

## 🛠️ Comandos Útiles

### Ver información del Container App
```bash
az containerapp show \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv
```

### Listar todas las revisiones
```bash
az containerapp revision list \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --output table
```

### Hacer rollback a una versión anterior
```bash
# 1. Listar revisiones
az containerapp revision list \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --output table

# 2. Activar una revisión específica
az containerapp revision set-mode \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --mode single \
  --revision sika-assistant-frontend-app--REVISION-NAME
```

### Escalar manualmente
```bash
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --min-replicas 2 \
  --max-replicas 10
```

### Reiniciar el Container App
```bash
az containerapp revision restart \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg
```

---

## 🔧 Actualizar URLs de Backend

Si cambias las URLs de los backends, debes:

### Opción 1: Redeploy completo
1. Edita las URLs en `deploy.sh` (líneas 27-28)
2. Ejecuta `./deploy.sh`

### Opción 2: Build y push manual
```bash
# Build con nuevas URLs
docker build \
  --build-arg VITE_WS_TEXT_URL=wss://nueva-url.com/ws/chat \
  --build-arg VITE_WS_VOICE_URL=wss://nueva-url.com/ws/voice \
  -t sika-assistant-frontend:latest .

# Login a ACR
az acr login --name sikaregistrytext

# Tag y push
docker tag sika-assistant-frontend:latest sikaregistrytext.azurecr.io/sika-assistant-frontend:latest
docker push sikaregistrytext.azurecr.io/sika-assistant-frontend:latest

# Actualizar Container App
az containerapp update \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --image sikaregistrytext.azurecr.io/sika-assistant-frontend:latest
```

---

## 🧪 Testing Local con Docker

Antes de desplegar a Azure, prueba localmente:

```bash
# Build
docker build \
  --build-arg VITE_WS_TEXT_URL=wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat \
  --build-arg VITE_WS_VOICE_URL=wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice \
  -t sika-frontend-test .

# Run
docker run -d -p 8080:80 --name sika-frontend-test sika-frontend-test

# Test
# Abre: http://localhost:8080

# Cleanup
docker stop sika-frontend-test
docker rm sika-frontend-test
```

---

## ❌ Eliminar Todos los Recursos

**⚠️ CUIDADO: Esto eliminará TODO el frontend de Azure**

```bash
# Solo el Container App
az containerapp delete \
  --name sika-assistant-frontend-app \
  --resource-group sika-container-rg \
  --yes

# Todo el Resource Group (si solo tienes el frontend)
az group delete \
  --name sika-container-rg \
  --yes
```

---

## 📊 Arquitectura del Deployment

```
┌─────────────────────────────────────────────┐
│  Usuario                                    │
│  https://frontend.azurecontainerapps.io     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  Azure Container Apps                       │
│  ┌─────────────────────────────────────┐   │
│  │  Frontend (Nginx)                   │   │
│  │  - HTML/CSS/JS estático             │   │
│  │  - Puerto 80                        │   │
│  │  - 1-5 replicas                     │   │
│  └──────────┬──────────────────────────┘   │
└─────────────┼───────────────────────────────┘
              │ WebSocket (wss://)
              │
        ┌─────┴─────┐
        ▼           ▼
┌──────────┐  ┌──────────┐
│ Text API │  │Voice API │
│ ws/chat  │  │ws/voice  │
└──────────┘  └──────────┘
```

---

## 📝 Troubleshooting

### La página carga pero dice "Desconectado"
- Verifica que los backends estén corriendo
- Verifica las URLs en el código desplegado:
  ```bash
  az containerapp revision list --name sika-assistant-frontend-app --resource-group sika-container-rg --output table
  ```

### Error de autenticación en ACR
```bash
az acr login --name sikaregistrytext
```

### El Container App no inicia
```bash
./logs.sh
# o
az containerapp logs show --name sika-assistant-frontend-app --resource-group sika-container-rg --follow
```

### Cambios no se reflejan
1. Verifica que el build se hizo correctamente
2. Verifica que la imagen se subió a ACR
3. Fuerza un restart:
   ```bash
   az containerapp revision restart --name sika-assistant-frontend-app --resource-group sika-container-rg
   ```

---

## 📞 Soporte

Si tienes problemas:
1. Revisa los logs: `./logs.sh`
2. Verifica las revisiones: `az containerapp revision list ...`
3. Prueba local primero: `docker run ...`
4. Verifica conectividad a backends

---

**¡Listo para desplegar! 🚀**
