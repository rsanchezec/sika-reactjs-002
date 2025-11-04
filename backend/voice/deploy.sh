#!/bin/bash

# ============================================
# Script de Deployment Automatizado
# Azure Container Apps - SIKA AI Assistant (Voice)
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
RESOURCE_GROUP="sika-container-rg"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-voice-api"   # ✅ Nombre correcto
ENVIRONMENT_NAME="sika-environment"
IMAGE_NAME="sika-assistant-voice"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"  # Tag único por fecha

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🚀 Azure Container Apps Deployment (Voice)${NC}"
echo -e "${GREEN}================================================${NC}\n"

# Verificar login
echo -e "${YELLOW}Verificando login de Azure...${NC}"
az account show > /dev/null 2>&1 || {
    echo -e "${RED}❌ No estás logueado en Azure. Ejecuta: az login${NC}"
    exit 1
}
echo -e "${GREEN}✅ Login verificado${NC}\n"

# Paso 1: Build
echo -e "${YELLOW}📦 Paso 1: Construyendo imagen Docker...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen construida${NC}\n"

# Paso 2: Login ACR
echo -e "${YELLOW}🔐 Paso 2: Login a Azure Container Registry...${NC}"
az acr login --name ${ACR_NAME}
echo -e "${GREEN}✅ Login exitoso${NC}\n"

# Paso 3: Push
echo -e "${YELLOW}⬆️  Paso 3: Subiendo imagen a ACR...${NC}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen subida: ${IMAGE_TAG}${NC}\n"

# Paso 4: Update Container App
echo -e "${YELLOW}🔄 Paso 4: Actualizando Container App...${NC}"
az containerapp update \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG} \
  --target-port 8001 \
  --output none

REVISION=$(az containerapp revision list \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --query "[0].name" -o tsv)

echo -e "${GREEN}✅ Container App actualizado (Revisión: ${REVISION})${NC}\n"

# Paso 5: URL
echo -e "${YELLOW}🌐 Paso 5: Obteniendo URL del servicio...${NC}"
FQDN=$(az containerapp show \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Deployment completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"
echo -e "${GREEN}📍 API:${NC} https://${FQDN}"
echo -e "${GREEN}🔌 WebSocket:${NC} wss://${FQDN}/ws/voice"
echo -e "${GREEN}📊 Health:${NC} https://${FQDN}/health"
echo -e "${GREEN}📚 Docs:${NC} https://${FQDN}/docs"
echo -e "${GREEN}🏷️  Imagen:${NC} ${IMAGE_TAG}\n"

# Paso 6: Logs opcional
read -p "¿Deseas ver los logs? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}📋 Mostrando logs...${NC}\n"
  az containerapp logs show \
    --name ${CONTAINER_APP_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --follow
fi
