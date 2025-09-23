@echo off
REM Kaspa Test Orchestrator - Zero Prerequisites Launcher for Windows
REM Supports both TESTNET and MAINNET

REM Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ========================================================================
    echo    KASPA TRANSACTION GENERATOR - REQUESTING ADMINISTRATOR RIGHTS
    echo ========================================================================
    echo.
    echo This script needs Administrator privileges to:
    echo  - Manage Docker containers
    echo  - Create necessary directories and files
    echo  - Ensure proper network configuration
    echo.
    echo Restarting with Administrator privileges...
    echo.

    REM Use PowerShell to elevate with better handling
    powershell -Command "Start-Process '%~f0' -Verb RunAs -ArgumentList '%*'"

    REM Exit the current non-elevated instance
    exit /b
)

REM Now running with admin rights - keep window open
cd /d "%~dp0"
color 0A
cls

echo ========================================================================
echo    KASPA TRANSACTION GENERATOR - ZERO INSTALL LAUNCHER
echo    Running with Administrator privileges
echo    Supports both TESTNET and MAINNET
echo ========================================================================
echo.

REM Check if Docker is installed and running
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Docker is not installed.
    echo.
    echo Would you like to:
    echo 1. Download and install Docker Desktop automatically
    echo 2. Exit and install Docker manually
    echo.
    set /p DOCKER_INSTALL=Choice [1/2]:

    if "%DOCKER_INSTALL%"=="1" goto :INSTALL_DOCKER

    echo.
    echo Please install Docker Desktop manually from:
    echo https://www.docker.com/products/docker-desktop
    echo.
    echo After installing Docker Desktop, run this script again.
    pause
    exit /b 1
)

docker ps >nul 2>&1
if %errorlevel% neq 0 (
    echo Docker is installed but not running.
    echo.
    echo Attempting to start Docker Desktop...

    REM Try to start Docker Desktop
    if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
        start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    ) else if exist "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe" (
        start "" "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe"
    ) else (
        echo Could not find Docker Desktop executable.
        echo Please start Docker Desktop manually and run this script again.
        pause
        exit /b 1
    )

    echo Waiting for Docker to start (this may take up to 60 seconds)...
    set COUNTER=0
    :WAIT_DOCKER
    set /a COUNTER+=1
    if %COUNTER% gtr 30 (
        echo.
        echo Docker is taking too long to start.
        echo Please ensure Docker Desktop is running and try again.
        pause
        exit /b 1
    )

    docker ps >nul 2>&1
    if %errorlevel% neq 0 (
        timeout /t 2 /nobreak >nul
        goto :WAIT_DOCKER
    )

    echo Docker started successfully!
    echo.
)

echo Docker is ready!
echo.

REM Create necessary directories
if not exist "config" mkdir config
if not exist "logs" mkdir logs

REM Check if we have a saved configuration
if exist "config\test_config.json" (
    echo Found existing configuration.
    set /p RECONFIGURE=Do you want to reconfigure? [y/N]:
    if /i not "%RECONFIGURE%"=="y" (
        REM Load existing config
        for /f "tokens=2 delims=:," %%i in ('type config\test_config.json ^| findstr "network"') do (
            set NETWORK=%%i
            set NETWORK=!NETWORK:"=!
            set NETWORK=!NETWORK: =!
        )
        goto :RUN_TEST
    )
)

:CONFIGURE
echo.
echo ==================== CONFIGURATION ====================
echo.

REM Network selection
echo NETWORK SELECTION:
echo 1. Testnet (for testing - no real funds)
echo 2. Mainnet (REAL NETWORK - USES REAL FUNDS!)
echo.
set /p NETWORK_CHOICE=Choice [1]:
if "%NETWORK_CHOICE%"=="" set NETWORK_CHOICE=1

if "%NETWORK_CHOICE%"=="2" (
    set NETWORK=mainnet

    echo.
    echo =====================================================
    echo                     WARNING!
    echo =====================================================
    echo You have selected MAINNET. This means:
    echo - You will be using REAL KAS funds
    echo - All transactions cost REAL money
    echo - High TPS rates can be expensive
    echo - Mistakes cannot be undone
    echo =====================================================
    echo.

    set /p CONFIRM=Type "MAINNET" to confirm you understand the risks:
    if not "%CONFIRM%"=="MAINNET" (
        echo Mainnet selection cancelled. Switching to testnet.
        set NETWORK=testnet
    )
) else (
    set NETWORK=testnet
)

REM Set network-specific parameters
if "%NETWORK%"=="mainnet" (
    set RPC_PORT=16110
    set P2P_PORT=16111
    set NETWORK_FLAG=--mainnet
    set NETWORK_NAME=mainnet
    set ADDRESS_PREFIX=kaspa:
    set DEFAULT_TPS=5
    set DEFAULT_DURATION=60
) else (
    set RPC_PORT=16210
    set P2P_PORT=16211
    set NETWORK_FLAG=--testnet
    set NETWORK_NAME=testnet10
    set ADDRESS_PREFIX=kaspatest:
    set DEFAULT_TPS=10
    set DEFAULT_DURATION=0
)

REM Wallet setup
echo.
echo WALLET SETUP:
if "%NETWORK%"=="mainnet" (
    echo For mainnet, you must use an existing wallet with funds.
    set WALLET_CHOICE=2
) else (
    echo 1. Generate new test wallet (testnet only)
    echo 2. Use existing private key
    echo.
    set /p WALLET_CHOICE=Choice [1]:
    if "%WALLET_CHOICE%"=="" set WALLET_CHOICE=1
)

if "%WALLET_CHOICE%"=="1" (
    REM Generate random hex key using PowerShell (more reliable)
    echo Generating secure private key...
    for /f %%i in ('powershell -command "[guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')"') do set PRIVATE_KEY=%%i

    echo.
    echo ====================================================
    echo Generated new private key:
    echo %PRIVATE_KEY%
    echo ====================================================
    echo IMPORTANT: Save this key somewhere safe!
    echo You'll need testnet KAS from: https://faucet.kaspad.net/
    echo ====================================================
    echo.
    pause
) else (
    echo.
    echo Enter your 64-character hex private key
    echo Expected address prefix: %ADDRESS_PREFIX%
    :INPUT_KEY
    set /p PRIVATE_KEY=Private key:

    REM Simple length check
    powershell -command "if('%PRIVATE_KEY%'.Length -ne 64){exit 1}" >nul 2>&1
    if %errorlevel% neq 0 (
        echo Invalid key format! Must be exactly 64 hexadecimal characters.
        goto :INPUT_KEY
    )
)

REM Test parameters
echo.
echo TEST PARAMETERS:

if "%NETWORK%"=="mainnet" (
    echo WARNING: High TPS on mainnet will cost more in fees!
)

set /p TPS=Target TPS (transactions per second) [%DEFAULT_TPS%]:
if "%TPS%"=="" set TPS=%DEFAULT_TPS%

if "%NETWORK%"=="mainnet" (
    echo WARNING: Long durations on mainnet will accumulate costs!
)

set /p DURATION=Duration in seconds (0=infinite) [%DEFAULT_DURATION%]:
if "%DURATION%"=="" set DURATION=%DEFAULT_DURATION%

if "%NETWORK%"=="mainnet" (
    if "%DURATION%"=="0" (
        echo.
        echo WARNING: Infinite duration on mainnet is not recommended!
        set /p CONFIRM_INFINITE=Are you sure? [y/N]:
        if /i not "%CONFIRM_INFINITE%"=="y" (
            set DURATION=60
            echo Duration set to 60 seconds for safety.
        )
    )
)

set /p UTXOS=Target UTXO count [100]:
if "%UTXOS%"=="" set UTXOS=100

REM Calculate estimated costs for mainnet
if "%NETWORK%"=="mainnet" (
    set /a ESTIMATED_TX_COUNT=%TPS%*%DURATION%
    if "%DURATION%"=="0" set /a ESTIMATED_TX_COUNT=%TPS%*3600

    echo.
    echo ====================================================
    echo ESTIMATED COSTS (MAINNET):
    echo TPS: %TPS%
    if "%DURATION%"=="0" (
        echo Duration: Infinite (estimated for 1 hour)
    ) else (
        echo Duration: %DURATION% seconds
    )
    echo Estimated transactions: %ESTIMATED_TX_COUNT%
    echo Note: Each transaction costs a small fee
    echo ====================================================
    echo.

    set /p CONFIRM_COSTS=Do you accept these estimated costs? [y/N]:
    if /i not "%CONFIRM_COSTS%"=="y" (
        echo Configuration cancelled.
        pause
        exit /b 0
    )
)

REM Save configuration to file
(
echo {
echo   "network": "%NETWORK%",
echo   "private_key": "%PRIVATE_KEY%",
echo   "tps": %TPS%,
echo   "duration": %DURATION%,
echo   "utxos": %UTXOS%
echo }
) > config\test_config.json

:RUN_TEST
REM Load configuration if we skipped configuration
if not defined PRIVATE_KEY (
    for /f "tokens=2 delims=:," %%i in ('type config\test_config.json ^| findstr "private_key"') do set PRIVATE_KEY=%%i
    set PRIVATE_KEY=%PRIVATE_KEY:"=%
    set PRIVATE_KEY=%PRIVATE_KEY: =%
)
if not defined TPS (
    for /f "tokens=2 delims=:," %%i in ('type config\test_config.json ^| findstr "tps"') do set TPS=%%i
    set TPS=%TPS: =%
)
if not defined DURATION (
    for /f "tokens=2 delims=:," %%i in ('type config\test_config.json ^| findstr "duration"') do set DURATION=%%i
    set DURATION=%DURATION: =%
)
if not defined NETWORK (
    for /f "tokens=2 delims=:," %%i in ('type config\test_config.json ^| findstr "network"') do set NETWORK=%%i
    set NETWORK=%NETWORK:"=%
    set NETWORK=%NETWORK: =%
)

REM Set network-specific parameters for loaded config
if "%NETWORK%"=="mainnet" (
    set RPC_PORT=16110
    set P2P_PORT=16111
    set NETWORK_FLAG=--mainnet
    set NETWORK_NAME=mainnet
) else (
    set RPC_PORT=16210
    set P2P_PORT=16211
    set NETWORK_FLAG=--testnet
    set NETWORK_NAME=testnet10
)

echo.
echo ==================== STARTING TEST ENVIRONMENT ====================
echo Network: %NETWORK%
if "%NETWORK%"=="mainnet" (
    echo WARNING: Using REAL FUNDS on MAINNET!
)
echo.

REM Create docker-compose.yml
echo Creating docker-compose.yml configuration...
(
echo version: '3.8'
echo.
echo services:
echo   kaspad:
echo     image: supertypo/kaspad:latest
echo     container_name: kaspad-%NETWORK%
echo     command:
echo       - kaspad
echo       - %NETWORK_FLAG%
echo       - --rpclisten=0.0.0.0:%RPC_PORT%
echo       - --rpcuser=user
echo       - --rpcpass=pass
echo       - --acceptanceindex
echo       - --utxoindex
echo     ports:
echo       - "%RPC_PORT%:%RPC_PORT%"
echo       - "%P2P_PORT%:%P2P_PORT%"
echo     volumes:
echo       - kaspad-%NETWORK%-data:/app/data
echo     networks:
echo       - kaspa-net
echo     restart: unless-stopped
echo.
echo   tx-builder:
echo     image: rust:1.75
echo     container_name: kaspa-tx-builder
echo     working_dir: /app
echo     volumes:
echo       - .:/app
echo       - cargo-cache:/usr/local/cargo/registry
echo       - cargo-git:/usr/local/cargo/git
echo       - target-cache:/app/rusty-kaspa/target
echo     networks:
echo       - kaspa-net
echo     command: bash -c "apt-get update && apt-get install -y protobuf-compiler libprotobuf-dev && cd /app/rusty-kaspa && PROTOC=/usr/bin/protoc cargo build --release --bin Tx_gen && echo 'Build complete!' && sleep infinity"
echo     restart: unless-stopped
echo.
echo   tx-runner:
echo     image: rust:1.75
echo     container_name: kaspa-tx-runner
echo     working_dir: /app/rusty-kaspa
echo     depends_on:
echo       - kaspad
echo       - tx-builder
echo     environment:
echo       - PRIVATE_KEY_HEX=%PRIVATE_KEY%
echo     volumes:
echo       - .:/app
echo       - target-cache:/app/rusty-kaspa/target
echo     networks:
echo       - kaspa-net
echo     command: bash -c "echo 'Waiting for build to complete...' && while [ ! -f /app/rusty-kaspa/target/release/Tx_gen ]; do sleep 2; done && echo 'Waiting for kaspad to be ready...' && sleep 10 && echo 'Starting transaction generator...' && /app/rusty-kaspa/target/release/Tx_gen --network %NETWORK_NAME% --target-tps %TPS% --duration %DURATION% --rpc-endpoint http://kaspad:%RPC_PORT%"
echo.
echo volumes:
echo   kaspad-%NETWORK%-data:
echo   cargo-cache:
echo   cargo-git:
echo   target-cache:
echo.
echo networks:
echo   kaspa-net:
echo     driver: bridge
) > docker-compose.yml

REM Start the services
echo Starting Kaspad node (%NETWORK%)...
docker-compose up -d kaspad

echo.
echo Building transaction generator (first time may take 5-10 minutes)...
docker-compose up -d tx-builder

echo.
echo Waiting for build to complete...
set BUILD_COUNTER=0
:WAIT_BUILD
set /a BUILD_COUNTER+=1
if %BUILD_COUNTER% gtr 300 (
    echo Build is taking too long. Check logs with: docker-compose logs tx-builder
    pause
    exit /b 1
)

docker-compose logs tx-builder 2>nul | findstr "Build complete!" >nul 2>&1
if %errorlevel% neq 0 (
    echo Still building... [%BUILD_COUNTER%/300]
    timeout /t 2 /nobreak >nul
    goto :WAIT_BUILD
)

echo.
echo Build complete! Starting transaction generator...
echo.
echo ==================== TRANSACTION GENERATOR RUNNING ====================
echo Network: %NETWORK%
echo Target TPS: %TPS%
echo Duration: %DURATION% seconds (0=infinite)
if "%NETWORK%"=="mainnet" (
    echo WARNING: Using REAL FUNDS on MAINNET!
)
echo Press Ctrl+C to stop
echo ========================================================================
echo.

docker-compose up tx-runner

echo.
echo ==================== TEST COMPLETED ====================
echo.
echo Options:
echo 1. Run test again with same configuration
echo 2. Reconfigure and run
echo 3. View logs
echo 4. Stop and clean up
echo 5. Exit
echo.
set /p POST_ACTION=Choice [5]:
if "%POST_ACTION%"=="" set POST_ACTION=5

if "%POST_ACTION%"=="1" (
    if "%NETWORK%"=="mainnet" (
        echo WARNING: This will use MORE real funds!
        set /p CONFIRM_RERUN=Continue? [y/N]:
        if /i not "%CONFIRM_RERUN%"=="y" goto :END
    )
    goto :RUN_TEST
)
if "%POST_ACTION%"=="2" (
    set PRIVATE_KEY=
    set TPS=
    set DURATION=
    set NETWORK=
    goto :CONFIGURE
)
if "%POST_ACTION%"=="3" (
    docker-compose logs --tail=100
    pause
    goto :END
)
if "%POST_ACTION%"=="4" (
    echo Stopping all containers...
    docker-compose down
    echo Clean up complete.
    pause
)

:END
pause
exit /b 0

:INSTALL_DOCKER
echo.
echo Downloading Docker Desktop installer...
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://desktop.docker.com/win/stable/Docker Desktop Installer.exe', '%TEMP%\DockerDesktopInstaller.exe')"

if not exist "%TEMP%\DockerDesktopInstaller.exe" (
    echo Failed to download Docker Desktop installer.
    echo Please install Docker manually from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

echo Installing Docker Desktop...
start /wait "" "%TEMP%\DockerDesktopInstaller.exe" install --quiet --accept-license

echo.
echo Docker Desktop installation initiated.
echo Please complete any remaining installation steps.
echo After installation is complete and Docker is running, run this script again.
pause
exit /b 0