#!/bin/bash

# ============================================
# Script de Configuración Inicial
# Azure Container Apps - SIKA AI Assistant
# ============================================
# Este script crea todos los recursos necesarios en Azure

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

# Configuración - EDITA ESTOS VALORES
RESOURCE_GROUP="sika-container-rg"            # Grupo de recursos (campo Resource group)
LOCATION="eastus"                             # Región (campo Region → East US)
ACR_NAME="sikaregistrytext"                   # Nombre del Azure Container Registry (solo si usas imágenes Docker)
CONTAINER_APP_NAME="sika-assistant-text-api"  # Nombre exacto del campo "Container app name"
ENVIRONMENT_NAME="sika-environment"           # Nombre del entorno de Container Apps (campo Container Apps environment)

# Pedir confirmación
echo -e "${YELLOW}Configuración:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Location: ${GREEN}${LOCATION}${NC}"
echo -e "  ACR Name: ${GREEN}${ACR_NAME}${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}\n"

read -p "¿Continuar con esta configuración? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${RED}Cancelado${NC}"
    exit 1
fi

# Verificar login
echo -e "\n${YELLOW}Verificando login de Azure...${NC}"
az account show > /dev/null 2>&1 || {
    echo -e "${RED}❌ No estás logueado. Ejecutando: az login${NC}"
    az login
}
echo -e "${GREEN}✅ Login verificado${NC}"

# Mostrar suscripción activa
SUBSCRIPTION=$(az account show --query name --output tsv)
echo -e "${GREEN}📋 Suscripción activa: ${SUBSCRIPTION}${NC}\n"

# Paso 1: Crear Resource Group
echo -e "${YELLOW}📦 Paso 1: Creando Resource Group...${NC}"
az group create \
  --name ${RESOURCE_GROUP} \
  --location ${LOCATION} \
  --output none
echo -e "${GREEN}✅ Resource Group creado: ${RESOURCE_GROUP}${NC}\n"

# Paso 2: Crear Azure Container Registry
echo -e "${YELLOW}🐳 Paso 2: Creando Azure Container Registry...${NC}"
az acr create \
  --resource-group ${RESOURCE_GROUP} \
  --name ${ACR_NAME} \
  --sku Basic \
  --admin-enabled true \
  --output none
echo -e "${GREEN}✅ ACR creado: ${ACR_NAME}${NC}\n"

# Obtener credenciales de ACR
echo -e "${YELLOW}🔐 Obteniendo credenciales de ACR...${NC}"
ACR_USERNAME=$(az acr credential show --name ${ACR_NAME} --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name ${ACR_NAME} --query passwords[0].value --output tsv)
echo -e "${GREEN}✅ Credenciales obtenidas${NC}"
echo -e "${BLUE}   Username: ${ACR_USERNAME}${NC}"
echo -e "${BLUE}   Password: ${ACR_PASSWORD:0:10}...${NC}\n"

# Paso 3: Crear Container App Environment
echo -e "${YELLOW}🌍 Paso 3: Creando Container App Environment...${NC}"
az containerapp env create \
  --name ${ENVIRONMENT_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --location ${LOCATION} \
  --output none
echo -e "${GREEN}✅ Environment creado: ${ENVIRONMENT_NAME}${NC}\n"

# Paso 4: Pedir variables de entorno sensibles
echo -e "${YELLOW}🔐 Paso 4: Configuración de variables de entorno${NC}"
echo -e "${BLUE}Por favor, ingresa los valores de Azure AI:${NC}\n"

read -p "PROJECT_CONNECTION_STRING: " CONNECTION_STRING
read -p "AZURE_AGENT_ID: " AGENT_ID
read -p "Frontend URL (ej: https://tuapp.azurewebsites.net): " FRONTEND_URL

# Paso 5: Build y push de imagen inicial
echo -e "\n${YELLOW}🏗️  Paso 5: Construyendo imagen Docker inicial...${NC}"
docker build -t sika-assistant:initial .
docker tag sika-assistant:initial ${ACR_NAME}.azurecr.io/sika-assistant:latest

echo -e "${YELLOW}📤 Subiendo imagen a ACR...${NC}"
az acr login --name ${ACR_NAME}
docker push ${ACR_NAME}.azurecr.io/sika-assistant:latest
echo -e "${GREEN}✅ Imagen subida${NC}\n"

# Paso 6: Crear Container App
echo -e "${YELLOW}🚀 Paso 6: Creando Container App...${NC}"
az containerapp create \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --environment ${ENVIRONMENT_NAME} \
  --image ${ACR_NAME}.azurecr.io/sika-assistant:latest \
  --registry-server ${ACR_NAME}.azurecr.io \
  --registry-username ${ACR_USERNAME} \
  --registry-password ${ACR_PASSWORD} \
  --target-port 8000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    "MODEL_DEPLOYMENT_NAME=gpt-4" \
    "ENVIRONMENT=production" \
    "ALLOWED_ORIGINS=${FRONTEND_URL}" \
  --secrets \
    "azure-connection-string=${CONNECTION_STRING}" \
    "azure-agent-id=${AGENT_ID}" \
  --env-vars \
    "PROJECT_CONNECTION_STRING=secretref:azure-connection-string" \
    "AZURE_AGENT_ID=secretref:azure-agent-id" \
  --output none

echo -e "${GREEN}✅ Container App creado${NC}\n"

# Paso 7: Obtener URL final
echo -e "${YELLOW}🌐 Paso 7: Obteniendo URL del servicio...${NC}"
FQDN=$(az containerapp show \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

# Resumen final
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Setup completado exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}📋 Resumen de recursos creados:${NC}"
echo -e "  Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "  Container Registry: ${GREEN}${ACR_NAME}.azurecr.io${NC}"
echo -e "  Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT_NAME}${NC}\n"

echo -e "${BLUE}🌐 URLs de tu servicio:${NC}"
echo -e "  API: ${GREEN}https://${FQDN}${NC}"
echo -e "  WebSocket: ${GREEN}wss://${FQDN}/ws/chat${NC}"
echo -e "  Health: ${GREEN}https://${FQDN}/health${NC}"
echo -e "  Docs: ${GREEN}https://${FQDN}/docs${NC}\n"

echo -e "${BLUE}🔐 Credenciales ACR:${NC}"
echo -e "  Username: ${GREEN}${ACR_USERNAME}${NC}"
echo -e "  Password: ${GREEN}${ACR_PASSWORD}${NC}\n"

echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo -e "  1. Actualiza tu frontend con la WebSocket URL: ${GREEN}wss://${FQDN}/ws/chat${NC}"
echo -e "  2. Verifica el health check: ${GREEN}https://${FQDN}/health${NC}"
echo -e "  3. Para actualizar: ${GREEN}./deploy.sh${NC}"
echo -e "  4. Ver logs: ${GREEN}az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --follow${NC}\n"

echo -e "${GREEN}¡Todo listo! 🎉${NC}\n"
