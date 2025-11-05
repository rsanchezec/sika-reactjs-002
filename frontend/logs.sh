#!/bin/bash

# ============================================
# Script para Ver Logs - FRONTEND
# Azure Container Apps - SIKA AI Assistant
# ============================================

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
RESOURCE_GROUP="sika-container-rg"
CONTAINER_APP_NAME="sika-assistant-frontend-app"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📋 Logs del Frontend${NC}"
echo -e "${BLUE}================================================${NC}\n"

echo -e "${YELLOW}Container App: ${GREEN}${CONTAINER_APP_NAME}${NC}"
echo -e "${YELLOW}Resource Group: ${GREEN}${RESOURCE_GROUP}${NC}\n"

echo -e "${BLUE}Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}\n"

az containerapp logs show \
  --name ${CONTAINER_APP_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --follow \
  --tail 50
