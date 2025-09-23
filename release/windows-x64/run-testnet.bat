@echo off
echo ===============================================
echo Kaspa Transaction Generator - Testnet Mode
echo ===============================================
echo.

REM Check if .env file exists
if not exist .env (
    if exist .env.example (
        echo ERROR: No .env file found!
        echo.
        echo Please copy .env.example to .env and add your private key:
        echo   1. copy .env.example .env
        echo   2. Edit .env and set PRIVATE_KEY_HEX
        echo.
        pause
        exit /b 1
    )
)

echo Starting transaction generator on TESTNET...
echo Press Ctrl+C to stop
echo.

Tx_gen.exe --network testnet10

pause