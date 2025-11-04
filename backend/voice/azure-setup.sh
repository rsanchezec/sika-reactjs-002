#!/bin/bash

# ============================================
# Script de Configuración Inicial
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
echo -e "${BLUE}🚀 Azure Container Apps - Initial Setup${NC}"
echo -e "${BLUE}================================================${NC}\n"

# ==================================================
# 🧩 Configuración - EDITA SOLO ESTAS VARIABLES
# ==================================================
RESOURCE_GROUP="sika-container-rg"
LOCATION="eastus"
ACR_NAME="sikaregistrytext"
CONTAINER_APP_NAME="sika-assistant-voice-api"
ENVIRONMENT_NAME="sika-environment"
IMAGE_NAME="sika-assistant-voice"
# ==================================================

# Mostrar configuración actual
echo -e "${YELLOW}Configuración:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Location: ${GREEN}${LOCATION}${NC}"
echo -e "  ACR Name: ${GREEN}${ACR_NAME}${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}"
echo -e "  Image Name: ${GREEN}${IMAGE_NAME}${NC}\n"

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

# Paso 4: Variables sensibles (AI + frontend)
echo -e "${YELLOW}🔐 Paso 4: Configuración de variables de entorno${NC}"
read -p "PROJECT_CONNECTION_STRING: " CONNECTION_STRING
read -p "AZURE_AGENT_ID: " AGENT_ID
read -p "Frontend URL (ej: https://tuapp.azurewebsites.net): " FRONTEND_URL

# Paso 4.1: Credenciales App Registration (EnvironmentCredential)
echo -e "${YELLOW}🔐 Paso 4.1: Credenciales de Azure App Registration...${NC}"
read -p "AZURE_TENANT_ID: " AZURE_TENANT_ID
read -p "AZURE_CLIENT_ID: " AZURE_CLIENT_ID
read -s -p "AZURE_CLIENT_SECRET (oculto): " AZURE_CLIENT_SECRET
echo

# Paso 5: Build & Push
echo -e "\n${YELLOW}🏗️  Paso 5: Construyendo imagen Docker inicial...${NC}"
docker build -t ${IMAGE_NAME}:initial .
docker tag ${IMAGE_NAME}:initial ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

echo -e "${YELLOW}📤 Subiendo imagen a ACR...${NC}"
az acr login --name ${ACR_NAME}
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
echo -e "${GREEN}✅ Imagen subida${NC}\n"

# Paso 6: Crear Container App (inyecta TODOS los secrets/env aquí)
echo -e "${YELLOW}🚀 Paso 6: Creando Container App...${NC}"
az containerapp create \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --environment ${ENVIRONMENT_NAME} \
  --image ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest \
  --registry-server ${ACR_NAME}.azurecr.io \
  --registry-username ${ACR_USERNAME} \
  --registry-password ${ACR_PASSWORD} \
  --target-port 8001 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --secrets \
    "azure-connection-string=${CONNECTION_STRING}" \
    "azure-agent-id=${AGENT_ID}" \
    "azure-tenant-id=${AZURE_TENANT_ID}" \
    "azure-client-id=${AZURE_CLIENT_ID}" \
    "azure-client-secret=${AZURE_CLIENT_SECRET}" \
  --env-vars \
    "MODEL_DEPLOYMENT_NAME=gpt-4" \
    "ENVIRONMENT=production" \
    "ALLOWED_ORIGINS=${FRONTEND_URL}" \
    "PROJECT_CONNECTION_STRING=secretref:azure-connection-string" \
    "AZURE_AGENT_ID=secretref:azure-agent-id" \
    "AZURE_TENANT_ID=secretref:azure-tenant-id" \
    "AZURE_CLIENT_ID=secretref:azure-client-id" \
    "AZURE_CLIENT_SECRET=secretref:azure-client-secret" \
  --output none

echo -e "${GREEN}✅ Container App creado${NC}\n"

# Paso 7: URL final
echo -e "${YELLOW}🌐 Paso 7: Obteniendo URL del servicio...${NC}"
FQDN=$(az containerapp show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --query properties.configuration.ingress.fqdn --output tsv)

# Resumen final
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Setup completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}📋 Resumen de recursos creados:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Container Registry: ${GREEN}${ACR_NAME}.azurecr.io${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}"
echo -e "  Image: ${GREEN}${IMAGE_NAME}${NC}\n"

echo -e "${BLUE}🌐 URLs de tu servicio:${NC}"
echo -e "  API: ${GREEN}https://${FQDN}${NC}"
echo -e "  WebSocket: ${GREEN}wss://${FQDN}/ws/voice${NC}"
echo -e "  Health: ${GREEN}https://${FQDN}/health${NC}"
echo -e "  Docs: ${GREEN}https://${FQDN}/docs${NC}\n"

echo -e "${BLUE}🔐 Credenciales ACR:${NC}"
echo -e "  Username: ${GREEN}${ACR_USERNAME}${NC}"
echo -e "  Password: ${GREEN}${ACR_PASSWORD}${NC}\n"

echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo -e "  1. Frontend → WebSocket URL: ${GREEN}wss://${FQDN}/ws/voice${NC}"
echo -e "  2. Health check: ${GREEN}https://${FQDN}/health${NC}"
echo -e "  3. Para actualizar: ${GREEN}./deploy.sh${NC}"
echo -e "  4. Logs: ${GREEN}az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --follow${NC}\n"

echo -e "${GREEN}¡Todo listo! 🎉${NC}\n"
