#Requires -Version 5.1

# Kaspa Test Orchestrator - PowerShell Version
# Zero prerequisites launcher - everything runs in Docker
# Supports both TESTNET and MAINNET
# Compatible with PowerShell 5.1 (default Windows version)

# Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "========================================================================" -ForegroundColor Yellow
    Write-Host "   KASPA TRANSACTION GENERATOR - REQUESTING ADMINISTRATOR RIGHTS" -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script needs Administrator privileges to:" -ForegroundColor White
    Write-Host "  - Manage Docker containers" -ForegroundColor White
    Write-Host "  - Create necessary directories and files" -ForegroundColor White
    Write-Host "  - Ensure proper network configuration" -ForegroundColor White
    Write-Host ""
    Write-Host "Restarting with Administrator privileges..." -ForegroundColor Cyan

    # Relaunch as administrator
    $arguments = "& '$($MyInvocation.MyCommand.Path)'"
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $arguments

    # Exit current session
    exit
}

# Now running with admin rights
Clear-Host
Write-Host "========================================================================" -ForegroundColor Green
Write-Host "   KASPA TRANSACTION GENERATOR - ZERO INSTALL LAUNCHER" -ForegroundColor Green
Write-Host "   Running with Administrator privileges" -ForegroundColor Green
Write-Host "   No prerequisites needed - everything runs in Docker!" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host ""

# Set working directory
Set-Location $PSScriptRoot

# Function to check Docker
function Test-Docker {
    try {
        $version = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to check if Docker daemon is running
function Test-DockerRunning {
    try {
        docker ps 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to start Docker Desktop
function Start-DockerDesktop {
    $dockerPaths = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe"
    )

    foreach ($path in $dockerPaths) {
        if (Test-Path $path) {
            Write-Host "Starting Docker Desktop..." -ForegroundColor Cyan
            Start-Process $path
            return $true
        }
    }
    return $false
}

# Check Docker installation
if (-not (Test-Docker)) {
    Write-Host "Docker is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Would you like to:" -ForegroundColor Yellow
    Write-Host "1. Download and install Docker Desktop automatically" -ForegroundColor White
    Write-Host "2. Exit and install Docker manually" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Choice [1/2]"

    if ($choice -eq "1") {
        Write-Host ""
        Write-Host "Downloading Docker Desktop installer..." -ForegroundColor Cyan
        $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

        try {
            Invoke-WebRequest -Uri "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" -OutFile $installerPath
            Write-Host "Starting Docker Desktop installation..." -ForegroundColor Cyan
            Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait
            Write-Host "Installation complete. Please restart this script." -ForegroundColor Green
        } catch {
            Write-Host "Failed to download or install Docker: $_" -ForegroundColor Red
        }
        Read-Host "Press Enter to exit"
        exit
    } else {
        Write-Host ""
        Write-Host "Please install Docker Desktop from:" -ForegroundColor Yellow
        Write-Host "https://www.docker.com/products/docker-desktop" -ForegroundColor Cyan
        Read-Host "Press Enter to exit"
        exit
    }
}

# Check if Docker daemon is running
if (-not (Test-DockerRunning)) {
    Write-Host "Docker is installed but not running." -ForegroundColor Yellow
    Write-Host ""

    if (Start-DockerDesktop) {
        Write-Host "Waiting for Docker to start (this may take up to 60 seconds)..." -ForegroundColor Cyan

        $counter = 0
        while ($counter -lt 30 -and -not (Test-DockerRunning)) {
            Start-Sleep -Seconds 2
            $counter++
            Write-Host "." -NoNewline
        }
        Write-Host ""

        if (Test-DockerRunning) {
            Write-Host "Docker started successfully!" -ForegroundColor Green
        } else {
            Write-Host "Docker failed to start. Please start Docker Desktop manually." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit
        }
    } else {
        Write-Host "Could not find Docker Desktop. Please start it manually." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }
}

Write-Host "Docker is ready!" -ForegroundColor Green
Write-Host ""

# Create necessary directories
if (-not (Test-Path "config")) {
    New-Item -ItemType Directory -Path "config" | Out-Null
}
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Configuration management
$configFile = "config\test_config.json"
$config = @{}

# Check for existing configuration
if (Test-Path $configFile) {
    Write-Host "Found existing configuration." -ForegroundColor Cyan
    $reconfigure = Read-Host "Do you want to reconfigure? [y/N]"

    if ($reconfigure -ne "y") {
        $config = Get-Content $configFile | ConvertFrom-Json
        $network = $config.network
        $privateKey = $config.private_key
        $tps = $config.tps
        $duration = $config.duration
        $utxos = $config.utxos

        # Ensure network is set (fallback to testnet if missing from old configs)
        if (-not $network) {
            Write-Host "Network not specified in config, defaulting to testnet" -ForegroundColor Yellow
            $network = "testnet"
        }
    }
}

# Configure if needed
if ($config.Count -eq 0) {
    Write-Host ""
    Write-Host "==================== CONFIGURATION ====================" -ForegroundColor Yellow
    Write-Host ""

    # Network selection
    Write-Host "NETWORK SELECTION:" -ForegroundColor Cyan
    Write-Host "1. Testnet (for testing - no real funds)" -ForegroundColor Green
    Write-Host "2. Mainnet (REAL NETWORK - USES REAL FUNDS)" -ForegroundColor Red
    Write-Host ""
    $networkChoice = Read-Host "Choice [1]"
    if ($networkChoice -eq "") { $networkChoice = "1" }

    if ($networkChoice -eq "2") {
        $network = "mainnet"

        Write-Host ""
        Write-Host "=====================================================" -ForegroundColor Red
        Write-Host "                    WARNING!" -ForegroundColor Red
        Write-Host "=====================================================" -ForegroundColor Red
        Write-Host "You have selected MAINNET. This means:" -ForegroundColor Yellow
        Write-Host "- You will be using REAL KAS funds" -ForegroundColor Yellow
        Write-Host "- All transactions cost REAL money" -ForegroundColor Yellow
        Write-Host "- High TPS rates can be expensive" -ForegroundColor Yellow
        Write-Host "- Mistakes cannot be undone" -ForegroundColor Yellow
        Write-Host "=====================================================" -ForegroundColor Red
        Write-Host ""

        $confirm = Read-Host "Type 'MAINNET' to confirm you understand the risks"
        if ($confirm -ne "MAINNET") {
            Write-Host "Mainnet selection cancelled. Switching to testnet." -ForegroundColor Green
            $network = "testnet"
        }
    } else {
        $network = "testnet"
    }

    # Set network-specific parameters
    if ($network -eq "mainnet") {
        $rpcPort = "16110"
        $p2pPort = "16111"
        $networkFlag = "--mainnet"
        $networkName = "mainnet"
        $addressPrefix = "kaspa:"
        $defaultTps = "5"  # Lower default for mainnet
        $defaultDuration = "60"  # 1 minute default for mainnet
    } else {
        $rpcPort = "16210"
        $p2pPort = "16211"
        $networkFlag = "--testnet"
        $networkName = "testnet10"
        $addressPrefix = "kaspatest:"
        $defaultTps = "10"
        $defaultDuration = "0"  # Infinite for testnet
    }

    # Wallet setup
    Write-Host ""
    Write-Host "WALLET SETUP:" -ForegroundColor Cyan
    Write-Host "1. Generate new wallet (testnet only)" -ForegroundColor White
    Write-Host "2. Use existing private key" -ForegroundColor White
    Write-Host ""

    if ($network -eq "mainnet") {
        Write-Host "Note: For mainnet, you must use an existing wallet with funds" -ForegroundColor Yellow
        $walletChoice = "2"
    } else {
        $walletChoice = Read-Host "Choice [1]"
        if ($walletChoice -eq "") { $walletChoice = "1" }
    }

    if ($walletChoice -eq "1") {
        Write-Host "Generating secure private key..." -ForegroundColor Cyan
        $guid1 = [guid]::NewGuid().ToString("N")
        $guid2 = [guid]::NewGuid().ToString("N")
        $privateKey = $guid1 + $guid2

        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "Generated new private key:" -ForegroundColor Green
        Write-Host $privateKey -ForegroundColor Yellow
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "IMPORTANT: Save this key somewhere safe!" -ForegroundColor Red
        Write-Host "You'll need testnet KAS from: https://faucet.kaspad.net/" -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to continue"
    } else {
        do {
            Write-Host ""
            Write-Host "Enter your 64-character hex private key" -ForegroundColor Cyan
            Write-Host "Expected address prefix: $addressPrefix" -ForegroundColor Yellow
            $privateKey = Read-Host "Private key"

            if ($privateKey.Length -ne 64) {
                Write-Host "Invalid key format! Must be exactly 64 hexadecimal characters." -ForegroundColor Red
            }
        } while ($privateKey.Length -ne 64)
    }

    # Test parameters
    Write-Host ""
    Write-Host "TEST PARAMETERS:" -ForegroundColor Cyan

    if ($network -eq "mainnet") {
        Write-Host "WARNING: High TPS on mainnet will cost more in fees!" -ForegroundColor Yellow
    }

    $tps = Read-Host "Target TPS (transactions per second) [$defaultTps]"
    if ($tps -eq "") { $tps = $defaultTps }

    if ($network -eq "mainnet") {
        Write-Host "WARNING: Long durations on mainnet will accumulate costs!" -ForegroundColor Yellow
    }

    $duration = Read-Host "Duration in seconds (0=infinite) [$defaultDuration]"
    if ($duration -eq "") { $duration = $defaultDuration }

    if ($network -eq "mainnet" -and $duration -eq "0") {
        Write-Host ""
        Write-Host "WARNING: Infinite duration on mainnet is not recommended!" -ForegroundColor Red
        $confirmInfinite = Read-Host "Are you sure? [y/N]"
        if ($confirmInfinite -ne "y") {
            $duration = "60"
            Write-Host "Duration set to 60 seconds for safety." -ForegroundColor Green
        }
    }

    $utxos = Read-Host "Target UTXO count [100]"
    if ($utxos -eq "") { $utxos = "100" }

    # Calculate estimated costs for mainnet
    if ($network -eq "mainnet") {
        $estimatedTxCount = [int]$tps * [int]$duration
        if ($duration -eq "0") { $estimatedTxCount = [int]$tps * 3600 }  # Estimate for 1 hour
        $estimatedFeesKAS = $estimatedTxCount * 0.00001  # Rough estimate

        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host "ESTIMATED COSTS (MAINNET):" -ForegroundColor Yellow
        Write-Host "TPS: $tps" -ForegroundColor White
        if ($duration -eq "0") {
            Write-Host "Duration: Infinite (estimated for 1 hour)" -ForegroundColor White
        } else {
            Write-Host "Duration: $duration seconds" -ForegroundColor White
        }
        Write-Host "Estimated transactions: $estimatedTxCount" -ForegroundColor White
        Write-Host "Estimated fees: ~$estimatedFeesKAS KAS" -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host ""

        $confirmCosts = Read-Host "Do you accept these estimated costs? [y/N]"
        if ($confirmCosts -ne "y") {
            Write-Host "Configuration cancelled." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit
        }
    }

    # Save configuration
    $config = @{
        network = $network
        private_key = $privateKey
        tps = [int]$tps
        duration = [int]$duration
        utxos = [int]$utxos
    }

    $config | ConvertTo-Json | Set-Content $configFile
}

# Load network-specific settings
if ($network -eq "mainnet") {
    $rpcPort = "16110"
    $p2pPort = "16111"
    $networkFlag = "--mainnet"
    $networkName = "mainnet"
} else {
    $rpcPort = "16210"
    $p2pPort = "16211"
    $networkFlag = "--testnet"
    $networkName = "testnet10"
}

Write-Host ""
Write-Host "==================== STARTING TEST ENVIRONMENT ====================" -ForegroundColor Yellow
$networkColor = if ($network -eq "mainnet") { "Red" } else { "Green" }
Write-Host "Network: $($network.ToUpper())" -ForegroundColor $networkColor

# Display the wallet address
Write-Host ""
Write-Host "==================== WALLET INFORMATION ====================" -ForegroundColor Cyan

# Try a simpler method first - check if Tx_gen is already built and use it
Write-Host "Deriving wallet address..." -ForegroundColor Gray

$addressInfo = $null

# Method 1: Try using the existing Tx_gen binary if it's been built
if (Test-Path "rusty-kaspa/target/release/Tx_gen") {
    Write-Host "Using existing transaction generator binary..." -ForegroundColor Gray
    $tempOutput = docker run --rm -v "${PWD}:/app" -e PRIVATE_KEY_HEX=$privateKey rust:latest bash -c "cd /app/rusty-kaspa && timeout 1 ./target/release/Tx_gen --network $networkName 2>&1 | grep 'Using address:' | sed 's/.*Using address: //' | head -1" 2>$null
    if ($tempOutput) {
        $addressInfo = $tempOutput
    }
}

# Method 2: Wait for it to be shown when tx-runner starts
if (-not $addressInfo) {
    Write-Host "Address will be displayed when the transaction generator starts..." -ForegroundColor Yellow
    $showAddressLater = $true
}

if ($addressInfo -and $addressInfo.Trim() -ne "") {
    $walletAddress = $addressInfo.Trim()

    Write-Host ""
    Write-Host "Your Kaspa Address:" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host $walletAddress -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host ""

    if ($network -eq "testnet") {
        Write-Host "To get testnet funds:" -ForegroundColor Green
        Write-Host "1. Visit: https://faucet.kaspad.net/" -ForegroundColor White
        Write-Host "2. Enter your address: $walletAddress" -ForegroundColor White
        Write-Host "3. Request testnet KAS" -ForegroundColor White
    } else {
        Write-Host "MAINNET - REAL FUNDS REQUIRED!" -ForegroundColor Red
        Write-Host "Send real KAS to the address above to fund your wallet." -ForegroundColor Yellow
        Write-Host "Make sure you have enough funds for:" -ForegroundColor Yellow
        Write-Host "  - Transaction fees" -ForegroundColor White
        Write-Host "  - UTXO splitting if needed" -ForegroundColor White
    }
} else {
    Write-Host "Note: Could not derive address. Address will be shown when transaction generator starts." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Create docker-compose.yml
Write-Host "Creating docker-compose.yml configuration..." -ForegroundColor Cyan

$dockerCompose = @"
services:
  kaspad:
    image: supertypo/rusty-kaspad:latest
    container_name: kaspad-$network
    command:
      - kaspad
      - $networkFlag
      - --rpclisten=0.0.0.0:$rpcPort
      - --utxoindex
    ports:
      - "$rpcPort`:$rpcPort"
      - "$p2pPort`:$p2pPort"
    volumes:
      - kaspad-$network-data:/app/data
    networks:
      - kaspa-net
    restart: unless-stopped

  tx-builder:
    image: rust:latest
    container_name: kaspa-tx-builder
    working_dir: /app
    volumes:
      - .:/app
      - cargo-cache:/usr/local/cargo/registry
      - cargo-git:/usr/local/cargo/git
      - target-cache:/app/rusty-kaspa/target
    networks:
      - kaspa-net
    command: bash -c "apt-get update && apt-get install -y protobuf-compiler libprotobuf-dev && cd /app/rusty-kaspa && PROTOC=/usr/bin/protoc cargo build --release --bin Tx_gen && echo 'Build complete!' && sleep infinity"
    restart: unless-stopped

  tx-runner:
    image: rust:latest
    container_name: kaspa-tx-runner
    working_dir: /app/rusty-kaspa
    depends_on:
      - kaspad
      - tx-builder
    environment:
      - PRIVATE_KEY_HEX=$privateKey
    volumes:
      - .:/app
      - target-cache:/app/rusty-kaspa/target
    networks:
      - kaspa-net
    command: bash -c "echo 'Waiting for build to complete...' && while [ ! -f /app/rusty-kaspa/target/release/Tx_gen ]; do sleep 2; done && echo 'Waiting for kaspad to be ready...' && for i in {1..60}; do if nc -zv kaspad $rpcPort 2>/dev/null; then echo 'Kaspad RPC port is open'; break; fi; echo 'Waiting for kaspad RPC port...'; sleep 2; done && echo 'Waiting for kaspad to sync (checking connectivity)...' && sleep 20 && echo 'Starting transaction generator...' && /app/rusty-kaspa/target/release/Tx_gen --network $networkName --target-tps $tps --duration $duration --rpc-endpoint grpc://kaspad:$rpcPort"

volumes:
  kaspad-$network-data:
  cargo-cache:
  cargo-git:
  target-cache:

networks:
  kaspa-net:
    driver: bridge
"@

$dockerCompose | Set-Content "docker-compose.yml"

# Start services
Write-Host "Starting Kaspad node ($network)..." -ForegroundColor Cyan
docker-compose up -d kaspad

Write-Host ""
Write-Host "Building transaction generator (first time may take 5-10 minutes)..." -ForegroundColor Cyan
Write-Host "This will run in parallel while kaspad syncs..." -ForegroundColor Gray
docker-compose up -d tx-builder

Write-Host ""
Write-Host "Waiting for build to complete (first build may take 10-20 minutes)..." -ForegroundColor Cyan
Write-Host "This process will wait indefinitely. Press Ctrl+C to cancel if needed." -ForegroundColor Yellow
Write-Host ""

$buildComplete = $false
$elapsedSeconds = 0
$lastStatus = ""

while (-not $buildComplete) {
    Start-Sleep -Seconds 5
    $elapsedSeconds += 5

    # Check if build is complete
    $logs = docker-compose logs tx-builder 2>$null
    if ($logs -match "Build complete!") {
        $buildComplete = $true
    } else {
        # Show progress every 30 seconds
        if ($elapsedSeconds % 30 -eq 0) {
            $minutes = [math]::Round($elapsedSeconds / 60, 1)

            # Check container status
            $containerStatus = docker ps --filter "name=kaspa-tx-builder" --format "{{.Status}}" 2>$null

            if ($containerStatus) {
                Write-Host "Still building... [$minutes minutes elapsed] - Container running" -ForegroundColor Gray

                # Try to get more detailed build status from logs
                $recentLogs = docker-compose logs --tail=3 tx-builder 2>$null
                if ($recentLogs) {
                    $lastLine = ($recentLogs -split "`n")[-1]
                    if ($lastLine -and $lastLine -ne $lastStatus) {
                        $lastStatus = $lastLine
                        # Extract just the package being compiled if it's a cargo output
                        if ($lastLine -match "Compiling\s+(\S+)") {
                            Write-Host "  Building: $($matches[1])" -ForegroundColor DarkGray
                        }
                    }
                }
            } else {
                Write-Host "Warning: Build container is not running!" -ForegroundColor Red
                Write-Host "Checking container status..." -ForegroundColor Yellow

                # Check if container exited with error
                $exitedContainer = docker ps -a --filter "name=kaspa-tx-builder" --format "{{.Status}}" 2>$null
                if ($exitedContainer -match "Exited") {
                    Write-Host "Build container exited. Showing last logs:" -ForegroundColor Red
                    docker-compose logs --tail=20 tx-builder
                    Write-Host "" -ForegroundColor Red
                    Write-Host "Build failed. You may need to:" -ForegroundColor Yellow
                    Write-Host "1. Run 'docker-compose down' to clean up" -ForegroundColor Yellow
                    Write-Host "2. Delete the 'target-cache' volume: 'docker volume rm a-simple-transaction-generator-for-kaspa_target-cache'" -ForegroundColor Yellow
                    Write-Host "3. Run this script again" -ForegroundColor Yellow
                    Read-Host "Press Enter to exit"
                    exit
                }
            }
        }
    }
}

Write-Host ""

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green

# NOW check if kaspad is synced before starting tx generator
Write-Host ""
Write-Host "Checking if Kaspad is synced..." -ForegroundColor Cyan
Write-Host "You can monitor kaspad logs with: docker logs -f kaspad-$network" -ForegroundColor Gray

$syncCheckAttempts = 0
$maxIdleMinutes = 3  # Maximum time without any activity before asking user
$lastActivityTime = Get-Date
$lastLogContent = ""
$isSynced = $false
$utxoSyncPattern = "Received .* UTXO set chunks"

Write-Host ""
Write-Host "Waiting for kaspad to sync" -NoNewline -ForegroundColor Yellow

while (-not $isSynced) {
    Start-Sleep -Seconds 10
    $syncCheckAttempts++

    # Show progress dots instead of repeating messages
    Write-Host "." -NoNewline -ForegroundColor Yellow

    # Check kaspad logs for activity
    $recentLogs = docker logs --tail=100 kaspad-$network 2>$null

    # Check if logs have changed (indicating activity)
    if ($recentLogs -ne $lastLogContent) {
        $lastActivityTime = Get-Date
        $lastLogContent = $recentLogs
    }

    # Calculate time since last activity
    $timeSinceActivity = (Get-Date) - $lastActivityTime
    $minutesSinceActivity = [math]::Round($timeSinceActivity.TotalMinutes, 1)

    # Check for different sync states
    if ($recentLogs -match $utxoSyncPattern) {
        # UTXO sync in progress - this is active syncing!
        if ($syncCheckAttempts % 3 -eq 0) {
            $utxoMatch = [regex]::Match($recentLogs, "Received (\d+) UTXO set chunks so far, totaling in (\d+) UTXOs")
            if ($utxoMatch.Success) {
                $chunks = $utxoMatch.Groups[1].Value
                $utxos = $utxoMatch.Groups[2].Value
                $minutes = [math]::Round($syncCheckAttempts * 10 / 60, 1)
                Write-Host "" # New line after dots
                Write-Host "Syncing UTXO set: $chunks chunks, $utxos UTXOs [$minutes min elapsed]" -ForegroundColor Cyan
                Write-Host "Still syncing" -NoNewline -ForegroundColor Yellow
            }
        }
    } elseif ($recentLogs -match "IBD completed") {
        # IBD (Initial Block Download) completed
        Write-Host "" # New line after dots
        Write-Host "[SYNCED] Initial block download completed!" -ForegroundColor Green
        $isSynced = $true
    } elseif ($recentLogs -match "Accepted block") {
        # Found accepted blocks - kaspad is syncing/synced
        $blockCount = ([regex]::Matches($recentLogs, "Accepted block")).Count

        # Check if sync rate has slowed down (indicating we're near the tip)
        if ($blockCount -le 5 -and $minutesSinceActivity -lt 1) {
            Write-Host "" # New line after dots
            Write-Host "[SYNCED] Kaspad is synced (at chain tip)" -ForegroundColor Green
            $isSynced = $true
        } else {
            # Only show status update every 30 seconds
            if ($syncCheckAttempts % 3 -eq 0) {
                $minutes = [math]::Round($syncCheckAttempts * 10 / 60, 1)
                Write-Host "" # New line after dots
                Write-Host "Syncing blocks: $blockCount recent blocks [$minutes min elapsed]" -ForegroundColor Cyan
                Write-Host "Still syncing" -NoNewline -ForegroundColor Yellow
            }
        }
    } else {
        # Check if kaspad is actually running
        $containerStatus = docker ps --filter "name=kaspad-$network" --format "{{.Status}}" 2>$null

        if (-not $containerStatus) {
            Write-Host "" # New line after dots
            Write-Host "[ERROR] Kaspad container is not running!" -ForegroundColor Red
            Write-Host "Check logs with: docker logs kaspad-$network" -ForegroundColor Yellow

            $startKaspad = Read-Host "Try to start kaspad again? [y/N]"
            if ($startKaspad -eq "y") {
                docker-compose up -d kaspad
                Write-Host "Restarted kaspad, waiting" -NoNewline -ForegroundColor Yellow
                $lastActivityTime = Get-Date  # Reset activity timer
            } else {
                exit
            }
        } elseif ($syncCheckAttempts % 3 -eq 0) {
            # Show status update every 30 seconds
            $minutes = [math]::Round($syncCheckAttempts * 10 / 60, 1)
            Write-Host "" # New line after dots
            Write-Host "Kaspad is starting up [$minutes min elapsed]" -ForegroundColor Gray

            # Show last few lines of kaspad log to see what's happening
            $lastLogLine = $recentLogs -split "`n" | Where-Object { $_ -match "\[INFO\]|\[WARN\]|\[ERROR\]" } | Select-Object -Last 1
            if ($lastLogLine) {
                # Truncate long lines for display
                if ($lastLogLine.Length -gt 100) {
                    $lastLogLine = $lastLogLine.Substring(0, 97) + "..."
                }
                Write-Host "Last activity: $lastLogLine" -ForegroundColor DarkGray
            }
            Write-Host "Waiting" -NoNewline -ForegroundColor Yellow
        }
    }

    # Check for timeout only if there's been no activity
    if ($minutesSinceActivity -gt $maxIdleMinutes) {
        Write-Host "" # New line
        Write-Host ""
        Write-Host "[WARNING] No new activity in kaspad logs for $minutesSinceActivity minutes." -ForegroundColor Yellow
        Write-Host "Last known status: Sync might be stalled or completed." -ForegroundColor Yellow
        Write-Host "You can check the full status with: docker logs --tail=50 kaspad-$network" -ForegroundColor Cyan
        Write-Host ""

        $continue = Read-Host "Continue anyway? [y/N]"
        if ($continue -eq "y") {
            Write-Host "Continuing with potentially unsynced node..." -ForegroundColor Yellow
            break
        } else {
            Write-Host "Waiting for more activity. Press Ctrl+C to exit." -ForegroundColor Cyan
            $lastActivityTime = Get-Date  # Reset timer if user chooses to wait
        }
    }
}

Write-Host "" # Final newline

Write-Host ""
Write-Host "Starting transaction generator..." -ForegroundColor Green
Write-Host ""
Write-Host "==================== TRANSACTION GENERATOR RUNNING ====================" -ForegroundColor Green
$networkColor = if ($network -eq "mainnet") { "Red" } else { "Green" }
Write-Host "Network: $($network.ToUpper())" -ForegroundColor $networkColor
Write-Host "Target TPS: $tps" -ForegroundColor White
Write-Host "Duration: $duration seconds (0=infinite)" -ForegroundColor White
if ($network -eq "mainnet") {
    Write-Host "WARNING: Using REAL FUNDS on MAINNET!" -ForegroundColor Red
}
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Green
Write-Host ""

# Run the transaction generator
docker-compose up tx-runner

Write-Host ""
Write-Host "==================== TEST COMPLETED ====================" -ForegroundColor Green
Write-Host ""

# Post-test menu
function Show-Menu {
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "1. Run test again with same configuration" -ForegroundColor White
    Write-Host "2. Reconfigure and run" -ForegroundColor White
    Write-Host "3. View logs" -ForegroundColor White
    Write-Host "4. Stop and clean up" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Choice [5]"
    if ($choice -eq "") { $choice = "5" }

    switch ($choice) {
        "1" {
            if ($network -eq "mainnet") {
                Write-Host "WARNING: This will use MORE real funds!" -ForegroundColor Red
                $confirm = Read-Host "Continue? [y/N]"
                if ($confirm -ne "y") {
                    Show-Menu
                    return
                }
            }
            docker-compose up tx-runner
            Show-Menu
        }
        "2" {
            Remove-Item $configFile -Force
            & $MyInvocation.MyCommand.Path
            exit
        }
        "3" {
            docker-compose logs --tail=100
            Read-Host "Press Enter to continue"
            Show-Menu
        }
        "4" {
            Write-Host "Stopping all containers..." -ForegroundColor Cyan
            docker-compose down
            Write-Host "Clean up complete." -ForegroundColor Green
            Read-Host "Press Enter to exit"
        }
        "5" {
            Write-Host "Exiting..." -ForegroundColor Cyan
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Show-Menu
        }
    }
}

Show-Menu
