#!/bin/bash

# ============================================
# Script de Deployment Automatizado
# Azure Container Apps - SIKA AI Assistant
# ============================================

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración (EDITA ESTOS VALORES)
RESOURCE_GROUP="sika-container-rg"            # Grupo de recursos (campo Resource group)
LOCATION="eastus"                             # Región (campo Region → East US)
ACR_NAME="sikaregistrytext"                   # Nombre del Azure Container Registry (solo si usas imágenes Docker)
CONTAINER_APP_NAME="sika-assistant-text-api"  # Nombre exacto del campo "Container app name"
ENVIRONMENT_NAME="sika-environment"           # Nombre del entorno de Container Apps (campo Container Apps environment)
IMAGE_NAME="sika-assistant"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"  # Tag con timestamp

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🚀 Azure Container Apps Deployment${NC}"
echo -e "${GREEN}================================================${NC}\n"

# Verificar que estamos logueados en Azure
echo -e "${YELLOW}Verificando login de Azure...${NC}"
az account show > /dev/null 2>&1 || {
    echo -e "${RED}❌ No estás logueado en Azure. Ejecuta: az login${NC}"
    exit 1
}
echo -e "${GREEN}✅ Login verificado${NC}\n"

# Paso 1: Construir imagen Docker
echo -e "${YELLOW}📦 Paso 1: Construyendo imagen Docker...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen construida${NC}\n"

# Paso 2: Login a ACR
echo -e "${YELLOW}🔐 Paso 2: Login a Azure Container Registry...${NC}"
az acr login --name ${ACR_NAME}
echo -e "${GREEN}✅ Login a ACR exitoso${NC}\n"

# Paso 3: Tag y push a ACR
echo -e "${YELLOW}⬆️  Paso 3: Subiendo imagen a ACR...${NC}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen subida: ${IMAGE_TAG}${NC}\n"

# Paso 4: Actualizar Container App
echo -e "${YELLOW}🔄 Paso 4: Actualizando Container App...${NC}"
az containerapp update \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}

echo -e "${GREEN}✅ Container App actualizado${NC}\n"

# Paso 5: Obtener URL
echo -e "${YELLOW}🌐 Paso 5: Obteniendo URL del servicio...${NC}"
FQDN=$(az containerapp show \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Deployment completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"
echo -e "${GREEN}📍 URL de la API:${NC} https://${FQDN}"
echo -e "${GREEN}🔌 WebSocket URL:${NC} wss://${FQDN}/ws/chat"
echo -e "${GREEN}📊 Health Check:${NC} https://${FQDN}/health"
echo -e "${GREEN}📚 API Docs:${NC} https://${FQDN}/docs"
echo -e "${GREEN}🏷️  Image Tag:${NC} ${IMAGE_TAG}\n"

# Paso 6: Ver logs (opcional)
read -p "¿Deseas ver los logs? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${YELLOW}📋 Mostrando logs...${NC}\n"
    az containerapp logs show \
      --name ${CONTAINER_APP_NAME} \
      --resource-group ${RESOURCE_GROUP} \
      --follow
fi
