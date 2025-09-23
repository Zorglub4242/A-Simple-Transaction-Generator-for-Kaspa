@echo off
echo ===============================================
echo Kaspa Transaction Generator - MAINNET Mode
echo ===============================================
echo.
echo WARNING: This will send real transactions on mainnet!
echo Make sure you understand the implications.
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

echo Are you sure you want to run on MAINNET? (Press Ctrl+C to cancel)
pause

echo Starting transaction generator on MAINNET...
echo Press Ctrl+C to stop
echo.

Tx_gen.exe --network mainnet

pause