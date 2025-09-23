#!/usr/bin/env python3
"""
Kaspa Zero-Install Test Orchestrator
Runs everything in Docker containers - no local prerequisites required!
Only requirement: Docker Desktop installed (or we'll help install it)
"""

import os
import sys
import json
import time
import platform
import subprocess
import tempfile
from pathlib import Path
from typing import Optional, Dict, List
import base64

class KaspaZeroInstallOrchestrator:
    """Zero-install orchestrator that runs everything in containers"""

    def __init__(self):
        self.os_type = platform.system()
        self.is_windows = self.os_type == "Windows"
        self.is_mac = self.os_type == "Darwin"
        self.is_linux = self.os_type == "Linux"
        self.work_dir = Path.cwd()
        self.config_dir = self.work_dir / ".kaspa_orchestrator"
        self.config_dir.mkdir(exist_ok=True)

    def run(self):
        """Main orchestration flow"""
        self.print_banner()

        # Only check for Docker - everything else runs in containers
        if not self.ensure_docker():
            self.offer_docker_alternative()
            return

        # Run the entire setup in a container
        if not self.run_orchestrator_container():
            return

        self.print_success("\n✅ Setup complete! Your test environment is ready.")
        self.print_info("Run './start_kaspa_test.sh' (Linux/Mac) or 'start_kaspa_test.bat' (Windows) to begin testing.")

    def print_banner(self):
        """Print welcome banner"""
        print("=" * 70)
        print("🚀 KASPA ZERO-INSTALL TEST ORCHESTRATOR")
        print("   No prerequisites needed - everything runs in containers!")
        print("=" * 70)
        print()

    def print_info(self, msg):
        print(f"ℹ️  {msg}")

    def print_success(self, msg):
        print(f"✅ {msg}")

    def print_error(self, msg):
        print(f"❌ {msg}")

    def print_warning(self, msg):
        print(f"⚠️  {msg}")

    def ensure_docker(self) -> bool:
        """Check if Docker is available"""
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                # Check if Docker daemon is running
                result = subprocess.run(
                    ["docker", "ps"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    self.print_success("Docker is ready!")
                    return True
                else:
                    self.print_warning("Docker is installed but not running.")
                    self.print_info("Please start Docker Desktop and run this script again.")
                    return False
            return False
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def offer_docker_alternative(self):
        """Offer alternatives when Docker is not available"""
        self.print_warning("Docker is not installed or not running.")
        print("\nYou have several options:")
        print("1. Install Docker Desktop from: https://www.docker.com/products/docker-desktop")
        print("2. Use our cloud-based testing service (coming soon)")
        print("3. Use the lightweight version with Podman (Linux only)")

        # Generate a one-click Docker installer script
        self.generate_docker_installer()

    def generate_docker_installer(self):
        """Generate platform-specific Docker installer"""
        if self.is_windows:
            installer_script = """@echo off
echo Installing Docker Desktop for Windows...
echo.
echo This will download and install Docker Desktop.
echo Please follow the installation wizard.
echo.
pause

:: Download Docker Desktop installer
powershell -Command "& {(New-Object System.Net.WebClient).DownloadFile('https://desktop.docker.com/win/stable/Docker Desktop Installer.exe', '%TEMP%\\DockerInstaller.exe')}"

:: Run installer
start /wait %TEMP%\\DockerInstaller.exe

echo.
echo Docker Desktop installation complete!
echo Please start Docker Desktop and run the orchestrator again.
pause
"""
            installer_path = Path("install_docker.bat")
            installer_path.write_text(installer_script)
            self.print_info(f"Created Docker installer: {installer_path}")
            self.print_info("Run 'install_docker.bat' to install Docker Desktop")

        elif self.is_mac:
            installer_script = """#!/bin/bash
echo "Installing Docker Desktop for Mac..."
echo ""
echo "Detecting architecture..."

if [[ $(uname -m) == 'arm64' ]]; then
    URL="https://desktop.docker.com/mac/stable/arm64/Docker.dmg"
    echo "Detected Apple Silicon (M1/M2)"
else
    URL="https://desktop.docker.com/mac/stable/amd64/Docker.dmg"
    echo "Detected Intel Mac"
fi

echo "Downloading Docker Desktop..."
curl -L "$URL" -o ~/Downloads/Docker.dmg

echo "Opening installer..."
open ~/Downloads/Docker.dmg

echo ""
echo "Please drag Docker to Applications folder in the opened window."
echo "After installation, start Docker Desktop and run the orchestrator again."
read -p "Press Enter to continue..."
"""
            installer_path = Path("install_docker.sh")
            installer_path.write_text(installer_script)
            installer_path.chmod(0o755)
            self.print_info(f"Created Docker installer: {installer_path}")
            self.print_info("Run './install_docker.sh' to install Docker Desktop")

        else:  # Linux
            installer_script = """#!/bin/bash
echo "Installing Docker on Linux..."
echo ""

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

case $OS in
    ubuntu|debian)
        echo "Installing Docker on $OS..."
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
        ;;
    fedora|centos|rhel)
        echo "Installing Docker on $OS..."
        sudo dnf -y install docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        ;;
    *)
        echo "Please install Docker manually for your distribution"
        echo "Visit: https://docs.docker.com/engine/install/"
        ;;
esac

echo ""
echo "Docker installation complete!"
echo "Please log out and back in for group changes to take effect."
echo "Then run the orchestrator again."
read -p "Press Enter to continue..."
"""
            installer_path = Path("install_docker.sh")
            installer_path.write_text(installer_script)
            installer_path.chmod(0o755)
            self.print_info(f"Created Docker installer: {installer_path}")
            self.print_info("Run './install_docker.sh' to install Docker")

    def run_orchestrator_container(self) -> bool:
        """Run the entire orchestration inside a container"""
        self.print_info("Setting up Kaspa test environment...")

        # Create Dockerfile for orchestrator
        dockerfile_content = """FROM python:3.11-slim

# Install necessary tools
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    build-essential \\
    pkg-config \\
    libssl-dev \\
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install protoc
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v24.3/protoc-24.3-linux-x86_64.zip \\
    && unzip protoc-24.3-linux-x86_64.zip -d /usr/local \\
    && rm protoc-24.3-linux-x86_64.zip

WORKDIR /app

# Copy the repository
COPY . .

# Build the transaction generator
RUN cd rusty-kaspa && cargo build --release --bin Tx_gen

# Create entrypoint script
RUN echo '#!/bin/bash\\n\\
echo "Kaspa Transaction Generator is ready!"\\n\\
cd /app/rusty-kaspa\\n\\
exec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
"""

        # Write Dockerfile
        dockerfile_path = self.work_dir / "Dockerfile.orchestrator"
        dockerfile_path.write_text(dockerfile_content)

        # Create docker-compose.yml for the complete setup
        compose_content = """version: '3.8'

services:
  kaspad:
    image: supertypo/kaspad:latest
    container_name: kaspad-testnet
    command:
      - kaspad
      - --testnet
      - --rpclisten=0.0.0.0:16210
      - --rpcuser=user
      - --rpcpass=pass
      - --acceptanceindex
      - --utxoindex
    ports:
      - "16210:16210"
      - "16211:16211"
    volumes:
      - kaspad-data:/app/data
    networks:
      - kaspa-net

  tx-generator:
    build:
      context: .
      dockerfile: Dockerfile.orchestrator
    container_name: kaspa-tx-gen
    depends_on:
      - kaspad
    environment:
      - PRIVATE_KEY_HEX=${PRIVATE_KEY_HEX}
      - KASPAD_HOST=kaspad
      - KASPAD_PORT=16210
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    networks:
      - kaspa-net
    stdin_open: true
    tty: true

volumes:
  kaspad-data:

networks:
  kaspa-net:
    driver: bridge
"""

        # Write docker-compose.yml
        compose_path = self.work_dir / "docker-compose.yml"
        compose_path.write_text(compose_content)

        # Create interactive setup script
        setup_script = """#!/usr/bin/env python3
import os
import json
import secrets
import re
from pathlib import Path

def setup_wallet():
    print("\\n=== Wallet Setup ===")
    print("1. Generate new test wallet")
    print("2. Use existing private key")

    choice = input("Choice [1]: ").strip() or "1"

    if choice == "1":
        private_key = secrets.token_hex(32)
        print(f"\\nGenerated private key: {private_key}")
        print("⚠️  Save this key! You'll need testnet KAS from https://faucet.kaspad.net/")
    else:
        while True:
            private_key = input("Enter 64-character hex private key: ").strip()
            if re.match(r'^[0-9a-fA-F]{64}$', private_key):
                break
            print("Invalid format. Must be 64 hex characters.")

    return private_key

def setup_test_params():
    print("\\n=== Test Configuration ===")

    tps = input("Target TPS (transactions/sec) [10]: ").strip() or "10"
    duration = input("Duration in seconds (0=infinite) [0]: ").strip() or "0"
    utxos = input("Target UTXO count [100]: ").strip() or "100"

    return {
        "tps": int(tps),
        "duration": int(duration),
        "utxos": int(utxos)
    }

def main():
    print("=" * 60)
    print("KASPA TEST ENVIRONMENT SETUP")
    print("=" * 60)

    # Setup wallet
    private_key = setup_wallet()

    # Setup test parameters
    params = setup_test_params()

    # Save configuration
    config = {
        "private_key": private_key,
        "test_params": params
    }

    config_dir = Path("/app/config")
    config_dir.mkdir(exist_ok=True)

    with open(config_dir / "test_config.json", "w") as f:
        json.dump(config, f, indent=2)

    # Create .env file
    with open("/app/.env", "w") as f:
        f.write(f"PRIVATE_KEY_HEX={private_key}\\n")

    print("\\n✅ Configuration saved!")
    print("\\nTo start the test, run:")
    print("  docker-compose exec tx-generator /app/rusty-kaspa/target/release/Tx_gen \\\\")
    print(f"    --network testnet10 \\\\")
    print(f"    --target-tps {params['tps']} \\\\")
    print(f"    --duration {params['duration']} \\\\")
    print(f"    --rpc-endpoint http://kaspad:16210")

if __name__ == "__main__":
    main()
"""

        # Write setup script
        setup_path = self.work_dir / "setup_in_container.py"
        setup_path.write_text(setup_script)

        # Create start scripts for different platforms
        if self.is_windows:
            start_script = """@echo off
echo Starting Kaspa Test Environment...
echo.

:: Check if containers are already running
docker-compose ps | findstr "kaspad" >nul 2>&1
if %errorlevel% equ 0 (
    echo Containers are already running.
    goto :menu
)

:: Build and start containers
echo Building containers (first time may take a few minutes)...
docker-compose build

echo.
echo Starting services...
docker-compose up -d

:: Wait for kaspad to be ready
echo.
echo Waiting for Kaspad node to initialize...
timeout /t 10 /nobreak >nul

:menu
echo.
echo ========================================
echo KASPA TEST ENVIRONMENT READY
echo ========================================
echo.
echo Options:
echo 1. Run interactive setup
echo 2. Start transaction generator
echo 3. View logs
echo 4. Stop all services
echo 5. Exit
echo.

set /p choice=Enter choice [1-5]:

if "%choice%"=="1" (
    docker-compose exec tx-generator python3 /app/setup_in_container.py
    goto :menu
)
if "%choice%"=="2" (
    docker-compose exec tx-generator bash -c "cd /app/rusty-kaspa && ./target/release/Tx_gen --network testnet10 --target-tps 10 --duration 0 --rpc-endpoint http://kaspad:16210"
    goto :menu
)
if "%choice%"=="3" (
    docker-compose logs -f
    goto :menu
)
if "%choice%"=="4" (
    docker-compose down
    echo Services stopped.
    pause
    exit
)
if "%choice%"=="5" (
    exit
)

goto :menu
"""
            start_path = Path("start_kaspa_test.bat")
            start_path.write_text(start_script)
            self.print_info(f"Created Windows starter: {start_path}")

        else:  # Linux/Mac
            start_script = """#!/bin/bash

echo "Starting Kaspa Test Environment..."
echo ""

# Color codes
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

# Check if containers are already running
if docker-compose ps | grep -q "kaspad"; then
    echo -e "${GREEN}Containers are already running.${NC}"
else
    # Build and start containers
    echo "Building containers (first time may take a few minutes)..."
    docker-compose build

    echo ""
    echo "Starting services..."
    docker-compose up -d

    # Wait for kaspad to be ready
    echo ""
    echo "Waiting for Kaspad node to initialize..."
    sleep 10
fi

# Interactive menu
while true; do
    echo ""
    echo "========================================"
    echo "KASPA TEST ENVIRONMENT READY"
    echo "========================================"
    echo ""
    echo "Options:"
    echo "1. Run interactive setup"
    echo "2. Start transaction generator"
    echo "3. View logs"
    echo "4. Stop all services"
    echo "5. Exit"
    echo ""
    read -p "Enter choice [1-5]: " choice

    case $choice in
        1)
            docker-compose exec tx-generator python3 /app/setup_in_container.py
            ;;
        2)
            docker-compose exec tx-generator bash -c "cd /app/rusty-kaspa && ./target/release/Tx_gen --network testnet10 --target-tps 10 --duration 0 --rpc-endpoint http://kaspad:16210"
            ;;
        3)
            docker-compose logs -f
            ;;
        4)
            docker-compose down
            echo "Services stopped."
            exit 0
            ;;
        5)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
done
"""
            start_path = Path("start_kaspa_test.sh")
            start_path.write_text(start_script)
            start_path.chmod(0o755)
            self.print_info(f"Created Unix starter: {start_path}")

        # Create a one-command quick start
        quickstart_content = """#!/bin/bash
# Kaspa Test - One Command Start

# Build and run everything
docker-compose up -d --build

# Wait for services
sleep 10

# Run with default settings
docker-compose exec tx-generator bash -c "
    export PRIVATE_KEY_HEX=0000000000000000000000000000000000000000000000000000000000000001
    cd /app/rusty-kaspa &&
    ./target/release/Tx_gen \\
        --network testnet10 \\
        --target-tps 10 \\
        --duration 60 \\
        --rpc-endpoint http://kaspad:16210
"
"""

        quickstart_path = Path("quickstart.sh")
        quickstart_path.write_text(quickstart_content)
        quickstart_path.chmod(0o755)

        self.print_success("Environment setup complete!")
        self.print_info("\nAll dependencies will be handled inside Docker containers.")
        self.print_info("No local installations required!")

        return True

def main():
    orchestrator = KaspaZeroInstallOrchestrator()
    try:
        orchestrator.run()
    except KeyboardInterrupt:
        print("\n\nSetup cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()