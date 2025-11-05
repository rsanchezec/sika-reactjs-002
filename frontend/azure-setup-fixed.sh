#!/bin/bash

# ============================================
# Script de Configuración - FRONTEND
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
echo -e "${BLUE}🚀 Azure Container Apps - Frontend Setup${NC}"
echo -e "${BLUE}================================================${NC}\n"

# ==================================================
# 🧩 Configuración - EDITA SOLO ESTAS VARIABLES
# ==================================================
RESOURCE_GROUP="sika-container-rg"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-frontend-app"
ENVIRONMENT_NAME="sika-environment"
IMAGE_NAME="sika-assistant-frontend"

# URLs de los backends (WebSockets)
BACKEND_TEXT_URL="wss://sika-assistant-text-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/chat"
BACKEND_VOICE_URL="wss://sika-assistant-voice-api.ambitiousforest-0f6169b7.eastus.azurecontainerapps.io/ws/voice"
# ==================================================

# Mostrar configuración actual
echo -e "${YELLOW}Configuración:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Location: ${GREEN}${LOCATION}${NC}"
echo -e "  ACR Name: ${GREEN}${ACR_NAME}${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}"
echo -e "  Image Name: ${GREEN}${IMAGE_NAME}${NC}"
echo -e "  Backend Text: ${GREEN}${BACKEND_TEXT_URL}${NC}"
echo -e "  Backend Voice: ${GREEN}${BACKEND_VOICE_URL}${NC}\n"

read -p "¿Continuar con esta configuración? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cancelado${NC}"
    exit 1
fi

# Verificar login
echo -e "\n${YELLOW}Verificando login de Azure...${NC}"
az account show > /dev/null 2>&1 || { echo -e "${RED}❌ No estás logueado. Ejecutando: az login${NC}"; az login; }
echo -e "${GREEN}✅ Login verificado${NC}"

# Suscripción activa
SUBSCRIPTION=$(az account show --query name --output tsv)
echo -e "${GREEN}📋 Suscripción activa: ${SUBSCRIPTION}${NC}\n"

# Paso 1: RG
echo -e "${YELLOW}📦 Paso 1: Verificando/creando Resource Group...${NC}"
if az group exists --name ${RESOURCE_GROUP} >/dev/null; then
  echo -e "${GREEN}✔ Resource Group existente: ${RESOURCE_GROUP}${NC}\n"
else
  az group create --name ${RESOURCE_GROUP} --location ${LOCATION} --output none
  echo -e "${GREEN}✅ Resource Group creado: ${RESOURCE_GROUP}${NC}\n"
fi

# Paso 2: ACR
echo -e "${YELLOW}🐳 Paso 2: Verificando/creando Azure Container Registry...${NC}"
if az acr show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} >/dev/null 2>&1; then
  echo -e "${GREEN}✔ ACR existente: ${ACR_NAME}${NC}\n"
else
  az acr create --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --sku Basic --admin-enabled true --output none
  echo -e "${GREEN}✅ ACR creado: ${ACR_NAME}${NC}\n"
fi

# Credenciales ACR
echo -e "${YELLOW}🔐 Obteniendo credenciales de ACR...${NC}"
ACR_USERNAME=$(az acr credential show --name ${ACR_NAME} --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name ${ACR_NAME} --query passwords[0].value --output tsv)
echo -e "${GREEN}✅ Credenciales obtenidas${NC}"
echo -e "${BLUE}   Username: ${ACR_USERNAME}${NC}"
echo -e "${BLUE}   Password: ${ACR_PASSWORD:0:10}...${NC}\n"

# Paso 3: Environment
echo -e "${YELLOW}🌍 Paso 3: Verificando/creando Container App Environment...${NC}"
if az containerapp env show --name ${ENVIRONMENT_NAME} --resource-group ${RESOURCE_GROUP} >/dev/null 2>&1; then
  echo -e "${GREEN}✔ Environment existente: ${ENVIRONMENT_NAME}${NC}\n"
else
  az containerapp env create --name ${ENVIRONMENT_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION} --output none
  echo -e "${GREEN}✅ Environment creado: ${ENVIRONMENT_NAME}${NC}\n"
fi

# Paso 4: Build & Push con URLs de backend
echo -e "\n${YELLOW}🏗️  Paso 4: Construyendo imagen Docker con URLs de backend...${NC}"
docker build \
  --build-arg VITE_WS_TEXT_URL=${BACKEND_TEXT_URL} \
  --build-arg VITE_WS_VOICE_URL=${BACKEND_VOICE_URL} \
  -t ${IMAGE_NAME}:latest .

docker tag ${IMAGE_NAME}:latest ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

echo -e "${YELLOW}📤 Subiendo imagen a ACR...${NC}"
az acr login --name ${ACR_NAME}
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen subida${NC}\n"

# Paso 5: Crear Container App (Frontend simple - solo Nginx)
echo -e "${YELLOW}🚀 Paso 5: Creando Container App para frontend...${NC}"
az containerapp create \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --environment ${ENVIRONMENT_NAME} \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest \
  --registry-server ${ACR_NAME}.azurecr.io \
  --registry-username ${ACR_USERNAME} \
  --registry-password ${ACR_PASSWORD} \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 5 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --output none

echo -e "${GREEN}✅ Container App creado${NC}\n"

# Paso 6: URL final
echo -e "${YELLOW}🌐 Paso 6: Obteniendo URL del frontend...${NC}"
FQDN=$(az containerapp show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --query properties.configuration.ingress.fqdn --output tsv)

# Resumen final
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Setup completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}📋 Resumen de recursos:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Container Registry: ${GREEN}${ACR_NAME}.azurecr.io${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}\n"

echo -e "${BLUE}🌐 URL de tu frontend:${NC}"
echo -e "  App: ${GREEN}https://${FQDN}${NC}\n"

echo -e "${BLUE}🔗 Se conecta a estos backends:${NC}"
echo -e "  Text API: ${GREEN}${BACKEND_TEXT_URL}${NC}"
echo -e "  Voice API: ${GREEN}${BACKEND_VOICE_URL}${NC}\n"

echo -e "${BLUE}🔐 Credenciales ACR:${NC}"
echo -e "  Username: ${GREEN}${ACR_USERNAME}${NC}"
echo -e "  Password: ${GREEN}${ACR_PASSWORD}${NC}\n"

echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo -e "  1. Abrir: ${GREEN}https://${FQDN}${NC}"
echo -e "  2. Para actualizar: ${GREEN}./deploy.sh${NC}"
echo -e "  3. Logs: ${GREEN}az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --follow${NC}\n"

echo -e "${GREEN}¡Frontend desplegado! 🎉${NC}\n"
