@echo off
REM Evidentia Quick Start Script for Windows
REM This batch file provides an easy way to run PowerShell scripts

echo ========================================
echo   Evidentia Quick Start
echo ========================================
echo.

if "%1"=="" goto menu
if "%1"=="generate" goto generate
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="channel" goto channel
if "%1"=="deploy" goto deploy
if "%1"=="demo" goto demo
if "%1"=="help" goto help
goto menu

:menu
echo Please select an option:
echo.
echo   1. generate  - Generate crypto materials
echo   2. start     - Start the network
echo   3. channel   - Create channel and join peers
echo   4. deploy    - Deploy chaincode
echo   5. stop      - Stop the network
echo   6. demo      - Run demo scenario
echo   7. help      - Show help
echo.
echo Usage: quick-start.bat [command]
echo Example: quick-start.bat start
echo.
set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" goto generate
if "%choice%"=="2" goto start
if "%choice%"=="3" goto channel
if "%choice%"=="4" goto deploy
if "%choice%"=="5" goto stop
if "%choice%"=="6" goto demo
if "%choice%"=="7" goto help
goto menu

:generate
echo.
echo Running Generate-Crypto.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0..\fabric-network\scripts\Generate-Crypto.ps1"
goto end

:start
echo.
echo Running Start-Network.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0..\fabric-network\scripts\Start-Network.ps1"
goto end

:stop
echo.
echo Running Stop-Network.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0..\fabric-network\scripts\Stop-Network.ps1"
goto end

:channel
echo.
echo Running Create-Channel.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0..\fabric-network\scripts\Create-Channel.ps1"
goto end

:deploy
echo.
echo Running Deploy-Chaincode.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0..\fabric-network\scripts\Deploy-Chaincode.ps1"
goto end

:demo
echo.
echo Running Run-Demo.ps1...
powershell -ExecutionPolicy Bypass -File "%~dp0Run-Demo.ps1"
goto end

:help
echo.
echo ========================================
echo   Evidentia Quick Start Help
echo ========================================
echo.
echo This script helps you manage the Evidentia blockchain network.
echo.
echo Commands:
echo   generate  - Generate all crypto materials (certificates, keys)
echo   start     - Start all Docker containers (orderer, peers, IPFS)
echo   channel   - Create the evidence channel and join peers
echo   deploy    - Package, install, and commit the chaincode
echo   stop      - Stop all Docker containers
echo   demo      - Run the demo scenario
echo.
echo First-time setup order:
echo   1. quick-start generate
echo   2. quick-start start
echo   3. quick-start channel
echo   4. quick-start deploy
echo.
echo Then start the backend and frontend manually:
echo   cd backend ^&^& npm run dev
echo   cd frontend ^&^& npm start
echo.
goto end

:end
echo.
echo Done.
pause

