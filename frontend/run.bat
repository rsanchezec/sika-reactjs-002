@echo off
echo Iniciando SIKA Frontend...
echo.

REM Verificar si node_modules existe
if not exist node_modules (
    echo Instalando dependencias...
    call npm install
    echo.
)

REM Iniciar servidor de desarrollo
call npm run dev
