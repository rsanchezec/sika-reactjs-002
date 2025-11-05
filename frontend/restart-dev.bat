@echo off
echo Limpiando cache de Vite...
rmdir /s /q .vite 2>nul
rmdir /s /q dist 2>nul

echo.
echo Iniciando servidor de desarrollo...
npm run dev
