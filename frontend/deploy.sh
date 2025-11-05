#!/bin/bash

# ============================================
# Script de Deployment - FRONTEND
# Azure Container Apps - SIKA AI Assistant
# ============================================
set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 Desplegando Frontend a Azure${NC}"
echo -e "${BLUE}================================================${NC}\n"

# ==================================================
# 🧩 Configuración - DEBE COINCIDIR CON azure-setup-fixed.sh
# ==================================================
RESOURCE_GROUP="sika-container-rg"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-frontend-app"
IMAGE_NAME="sika-assistant-frontend"

# URLs de los backends (WebSockets)
BACKEND_TEXT_URL="wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat"
BACKEND_VOICE_URL="wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice"
# ==================================================

# Generar timestamp para versionado
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
VERSION_TAG="v${TIMESTAMP}"

echo -e "${YELLOW}📋 Configuración del deployment:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  ACR: ${GREEN}${ACR_NAME}.azurecr.io${NC}"
echo -e "  Image: ${GREEN}${IMAGE_NAME}${NC}"
echo -e "  Version: ${GREEN}${VERSION_TAG}${NC}\n"

# Verificar login
echo -e "${YELLOW}🔐 Verificando login de Azure...${NC}"
az account show > /dev/null 2>&1 || { echo -e "${RED}❌ No estás logueado. Ejecuta: az login${NC}"; exit 1; }
echo -e "${GREEN}✅ Login verificado${NC}\n"

# Paso 1: Build
echo -e "${YELLOW}🏗️  Paso 1/4: Construyendo imagen Docker...${NC}"
echo -e "${BLUE}   Backend Text URL: ${BACKEND_TEXT_URL}${NC}"
echo -e "${BLUE}   Backend Voice URL: ${BACKEND_VOICE_URL}${NC}\n"

docker build \
  --build-arg VITE_WS_TEXT_URL=${BACKEND_TEXT_URL} \
  --build-arg VITE_WS_VOICE_URL=${BACKEND_VOICE_URL} \
  -t ${IMAGE_NAME}:${VERSION_TAG} \
  -t ${IMAGE_NAME}:latest \
  .

echo -e "${GREEN}✅ Imagen construida${NC}\n"

# Paso 2: Tag para ACR
echo -e "${YELLOW}🏷️  Paso 2/4: Etiquetando imágenes...${NC}"
docker tag ${IMAGE_NAME}:${VERSION_TAG} ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${VERSION_TAG}
docker tag ${IMAGE_NAME}:latest ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imágenes etiquetadas${NC}\n"

# Paso 3: Push a ACR
echo -e "${YELLOW}📤 Paso 3/4: Subiendo imágenes a ACR...${NC}"
az acr login --name ${ACR_NAME}

echo -e "${BLUE}   Subiendo ${VERSION_TAG}...${NC}"
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${VERSION_TAG}

echo -e "${BLUE}   Subiendo latest...${NC}"
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

echo -e "${GREEN}✅ Imágenes subidas a ACR${NC}\n"

# Paso 4: Actualizar Container App
echo -e "${YELLOW}🔄 Paso 4/4: Actualizando Container App...${NC}"
az containerapp update \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${VERSION_TAG} \
  --output none

echo -e "${GREEN}✅ Container App actualizado${NC}\n"

# Obtener URL
echo -e "${YELLOW}🌐 Obteniendo información del servicio...${NC}"
FQDN=$(az containerapp show \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

# Resumen final
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Deployment completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}📦 Versión desplegada:${NC}"
echo -e "  Image: ${GREEN}${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${VERSION_TAG}${NC}"
echo -e "  Tag latest: ${GREEN}${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest${NC}\n"

echo -e "${BLUE}🌐 URL del frontend:${NC}"
echo -e "  ${GREEN}https://${FQDN}${NC}\n"

echo -e "${BLUE}🔗 Conectado a:${NC}"
echo -e "  Text API: ${GREEN}${BACKEND_TEXT_URL}${NC}"
echo -e "  Voice API: ${GREEN}${BACKEND_VOICE_URL}${NC}\n"

echo -e "${YELLOW}📝 Comandos útiles:${NC}"
echo -e "  Ver logs: ${GREEN}az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --follow${NC}"
echo -e "  Ver revisiones: ${GREEN}az containerapp revision list --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --output table${NC}"
echo -e "  Rollback: ${GREEN}az containerapp revision set-mode --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --mode single --revision <REVISION_NAME>${NC}\n"

echo -e "${GREEN}¡Frontend actualizado! 🎉${NC}"
echo -e "${BLUE}Abre: https://${FQDN}${NC}\n"
