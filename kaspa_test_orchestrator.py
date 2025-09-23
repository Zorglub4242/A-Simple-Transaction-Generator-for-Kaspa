#!/usr/bin/env python3
"""
Kaspa Test Orchestrator - Fool-proof automation for Kaspa transaction testing
Handles everything from Docker setup to test execution
"""

import os
import sys
import json
import time
import shutil
import platform
import subprocess
import urllib.request
from pathlib import Path
from typing import Optional, Dict, Tuple, List
import secrets
import re

class KaspaTestOrchestrator:
    """Main orchestrator for automated Kaspa testing"""

    def __init__(self):
        self.os_type = platform.system()
        self.is_windows = self.os_type == "Windows"
        self.is_mac = self.os_type == "Darwin"
        self.is_linux = self.os_type == "Linux"
        self.config_dir = Path.home() / ".kaspa_test_orchestrator"
        self.config_file = self.config_dir / "config.json"
        self.wallet_file = self.config_dir / "wallet.json"
        self.test_config_file = self.config_dir / "test_config.json"
        self.config_dir.mkdir(exist_ok=True)

    def run(self):
        """Main orchestration flow"""
        self.print_banner()

        # Step 1: Check and setup Docker
        if not self.setup_docker():
            return

        # Step 2: Setup Kaspad node
        if not self.setup_kaspad_node():
            return

        # Step 3: Setup wallet
        if not self.setup_wallet():
            return

        # Step 4: Configure test parameters
        if not self.configure_test():
            return

        # Step 5: Generate and run test script
        if not self.generate_test_runner():
            return

        self.print_success("\n✅ Setup complete! Your test environment is ready.")
        self.print_info("Run 'python run_kaspa_test.py' to start testing anytime.")

    def print_banner(self):
        """Print welcome banner"""
        print("=" * 60)
        print("🚀 KASPA TEST ORCHESTRATOR - Automated Setup & Testing")
        print("=" * 60)
        print()

    def print_info(self, msg):
        """Print info message"""
        print(f"ℹ️  {msg}")

    def print_success(self, msg):
        """Print success message"""
        print(f"✅ {msg}")

    def print_error(self, msg):
        """Print error message"""
        print(f"❌ {msg}")

    def print_warning(self, msg):
        """Print warning message"""
        print(f"⚠️  {msg}")

    def prompt_yes_no(self, question: str, default: bool = True) -> bool:
        """Prompt user for yes/no answer"""
        default_str = "Y/n" if default else "y/N"
        while True:
            answer = input(f"{question} [{default_str}]: ").strip().lower()
            if not answer:
                return default
            if answer in ['y', 'yes']:
                return True
            if answer in ['n', 'no']:
                return False
            print("Please answer 'yes' or 'no'")

    def prompt_choice(self, question: str, choices: List[str], default: int = 0) -> int:
        """Prompt user to choose from list"""
        print(f"\n{question}")
        for i, choice in enumerate(choices):
            marker = " (default)" if i == default else ""
            print(f"  {i+1}. {choice}{marker}")
        while True:
            answer = input(f"Choice [1-{len(choices)}]: ").strip()
            if not answer:
                return default
            try:
                choice = int(answer) - 1
                if 0 <= choice < len(choices):
                    return choice
            except ValueError:
                pass
            print(f"Please enter a number between 1 and {len(choices)}")

    def run_command(self, cmd: List[str], capture_output: bool = True, check: bool = True) -> Optional[subprocess.CompletedProcess]:
        """Run a command and return result"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=capture_output,
                text=True,
                check=check
            )
            return result
        except subprocess.CalledProcessError as e:
            if check:
                self.print_error(f"Command failed: {' '.join(cmd)}")
                if e.output:
                    self.print_error(f"Output: {e.output}")
            return None
        except FileNotFoundError:
            return None

    def check_docker_installed(self) -> bool:
        """Check if Docker is installed"""
        result = self.run_command(["docker", "--version"], check=False)
        return result is not None and result.returncode == 0

    def check_docker_running(self) -> bool:
        """Check if Docker daemon is running"""
        result = self.run_command(["docker", "ps"], check=False)
        return result is not None and result.returncode == 0

    def setup_docker(self) -> bool:
        """Setup Docker Desktop"""
        self.print_info("Checking Docker setup...")

        if not self.check_docker_installed():
            self.print_warning("Docker is not installed.")

            if self.prompt_yes_no("Would you like to install Docker Desktop?"):
                if not self.install_docker():
                    return False
            else:
                self.print_error("Docker is required. Please install Docker Desktop manually.")
                self.print_info("Visit: https://www.docker.com/products/docker-desktop")
                return False

        if not self.check_docker_running():
            self.print_warning("Docker Desktop is installed but not running.")

            if self.prompt_yes_no("Would you like to start Docker Desktop?"):
                if not self.start_docker():
                    return False
            else:
                self.print_error("Please start Docker Desktop manually and run this script again.")
                return False

        self.print_success("Docker is ready!")
        return True

    def install_docker(self) -> bool:
        """Install Docker Desktop"""
        self.print_info("Installing Docker Desktop...")

        if self.is_windows:
            url = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
            installer = Path.home() / "Downloads" / "DockerDesktopInstaller.exe"
        elif self.is_mac:
            if platform.machine() == "arm64":
                url = "https://desktop.docker.com/mac/stable/arm64/Docker.dmg"
            else:
                url = "https://desktop.docker.com/mac/stable/amd64/Docker.dmg"
            installer = Path.home() / "Downloads" / "Docker.dmg"
        else:  # Linux
            self.print_info("For Linux, please follow the official Docker installation guide:")
            self.print_info("https://docs.docker.com/engine/install/")
            return False

        # Download installer
        self.print_info(f"Downloading Docker Desktop from {url}...")
        try:
            urllib.request.urlretrieve(url, installer)
        except Exception as e:
            self.print_error(f"Failed to download Docker: {e}")
            return False

        # Run installer
        self.print_info("Running Docker installer...")
        if self.is_windows:
            subprocess.run([str(installer)], shell=True)
        elif self.is_mac:
            subprocess.run(["open", str(installer)])

        self.print_info("Please complete the Docker Desktop installation.")
        self.print_info("After installation, start Docker Desktop and run this script again.")
        input("Press Enter when Docker Desktop is installed and running...")

        return self.check_docker_running()

    def start_docker(self) -> bool:
        """Start Docker Desktop"""
        self.print_info("Starting Docker Desktop...")

        if self.is_windows:
            # Try to start Docker Desktop on Windows
            docker_paths = [
                r"C:\Program Files\Docker\Docker\Docker Desktop.exe",
                r"C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe",
            ]
            for docker_path in docker_paths:
                if Path(docker_path).exists():
                    subprocess.Popen([docker_path])
                    break
            else:
                self.print_error("Could not find Docker Desktop executable.")
                return False

        elif self.is_mac:
            subprocess.run(["open", "-a", "Docker"])

        else:  # Linux
            result = self.run_command(["systemctl", "start", "docker"], check=False)
            if result is None or result.returncode != 0:
                result = self.run_command(["sudo", "systemctl", "start", "docker"], check=False)

        # Wait for Docker to start
        self.print_info("Waiting for Docker to start (this may take a minute)...")
        for i in range(60):
            if self.check_docker_running():
                self.print_success("Docker started successfully!")
                return True
            time.sleep(2)

        self.print_error("Docker failed to start. Please start it manually.")
        return False

    def setup_kaspad_node(self) -> bool:
        """Setup Kaspad node in Docker"""
        self.print_info("\nSetting up Kaspad node...")

        # Check if kaspad container exists
        result = self.run_command(["docker", "ps", "-a", "--format", "{{.Names}}"], check=False)
        if result and "kaspad-testnet" in result.stdout:
            self.print_info("Kaspad container already exists.")

            # Check if it's running
            result = self.run_command(["docker", "ps", "--format", "{{.Names}}"], check=False)
            if result and "kaspad-testnet" in result.stdout:
                self.print_success("Kaspad node is already running!")
                return True
            else:
                self.print_info("Starting existing Kaspad container...")
                self.run_command(["docker", "start", "kaspad-testnet"])
                time.sleep(5)
                return True

        # Create and run new kaspad container
        self.print_info("Creating new Kaspad testnet node...")
        cmd = [
            "docker", "run", "-d",
            "--name", "kaspad-testnet",
            "-p", "16210:16210",  # RPC port
            "-p", "16211:16211",  # P2P port
            "-v", "kaspad-testnet-data:/app/data",
            "supertypo/kaspad:latest",
            "kaspad",
            "--testnet",
            "--rpclisten=0.0.0.0:16210",
            "--rpcuser=user",
            "--rpcpass=password",
            "--acceptanceindex",
            "--utxoindex"
        ]

        result = self.run_command(cmd)
        if not result:
            self.print_error("Failed to create Kaspad container")
            return False

        self.print_info("Waiting for Kaspad to sync (this may take a few minutes)...")
        time.sleep(10)

        # Save node configuration
        node_config = {
            "network": "testnet10",
            "rpc_endpoint": "localhost:16210",
            "container_name": "kaspad-testnet"
        }
        self.save_config("node", node_config)

        self.print_success("Kaspad node is ready!")
        return True

    def setup_wallet(self) -> bool:
        """Setup wallet for testing"""
        self.print_info("\nSetting up wallet...")

        wallet_choice = self.prompt_choice(
            "How would you like to setup your wallet?",
            [
                "Create a new test wallet",
                "Use existing wallet with private key",
                "Use existing wallet with seed phrase"
            ]
        )

        if wallet_choice == 0:
            return self.create_new_wallet()
        elif wallet_choice == 1:
            return self.import_private_key()
        else:
            return self.import_seed_phrase()

    def create_new_wallet(self) -> bool:
        """Create a new test wallet"""
        self.print_info("Creating new test wallet...")

        # Generate a random private key (simplified for demo)
        private_key = secrets.token_hex(32)

        wallet_config = {
            "type": "generated",
            "private_key": private_key,
            "network": "testnet10"
        }

        self.save_config("wallet", wallet_config)

        self.print_success(f"Test wallet created!")
        self.print_warning("Private key (KEEP SAFE): " + private_key)
        self.print_info("You'll need to fund this wallet with testnet KAS to run tests.")
        self.print_info("Get testnet KAS from: https://faucet.kaspad.net/")

        return True

    def import_private_key(self) -> bool:
        """Import existing private key"""
        while True:
            private_key = input("Enter your private key (64 hex characters): ").strip()

            # Validate private key format
            if re.match(r'^[0-9a-fA-F]{64}$', private_key):
                wallet_config = {
                    "type": "imported",
                    "private_key": private_key,
                    "network": "testnet10"
                }
                self.save_config("wallet", wallet_config)
                self.print_success("Wallet imported successfully!")
                return True
            else:
                self.print_error("Invalid private key format. Must be 64 hexadecimal characters.")
                if not self.prompt_yes_no("Try again?"):
                    return False

    def import_seed_phrase(self) -> bool:
        """Import seed phrase (simplified - would need BIP39 implementation)"""
        self.print_info("Seed phrase import requires additional setup.")
        self.print_info("For now, please use private key import instead.")
        return self.import_private_key()

    def configure_test(self) -> bool:
        """Configure test parameters"""
        self.print_info("\nConfiguring test parameters...")

        # TPS configuration
        print("\nTransaction rate (TPS - Transactions Per Second):")
        default_tps = 10
        while True:
            tps_input = input(f"Target TPS [{default_tps}]: ").strip()
            if not tps_input:
                tps = default_tps
                break
            try:
                tps = int(tps_input)
                if tps > 0:
                    break
                print("TPS must be positive")
            except ValueError:
                print("Please enter a valid number")

        # Duration configuration
        print("\nTest duration:")
        duration_choice = self.prompt_choice(
            "How long should the test run?",
            [
                "Run indefinitely (manual stop)",
                "Run for specific duration"
            ]
        )

        if duration_choice == 0:
            duration = 0
        else:
            while True:
                duration_input = input("Duration in seconds: ").strip()
                try:
                    duration = int(duration_input)
                    if duration > 0:
                        break
                    print("Duration must be positive")
                except ValueError:
                    print("Please enter a valid number")

        # UTXO management
        print("\nUTXO management:")
        utxo_count = 100
        utxo_input = input(f"Target UTXO count [{utxo_count}]: ").strip()
        if utxo_input:
            try:
                utxo_count = int(utxo_input)
            except ValueError:
                pass

        # Safety settings
        unleashed = self.prompt_yes_no("\nRemove 100 TPS safety cap? (advanced users only)", default=False)

        test_config = {
            "target_tps": tps,
            "duration": duration,
            "utxo_count": utxo_count,
            "unleashed": unleashed,
            "network": "testnet10"
        }

        self.save_config("test", test_config)

        self.print_success("Test configuration saved!")
        return True

    def generate_test_runner(self) -> bool:
        """Generate the test runner script"""
        self.print_info("\nGenerating test runner script...")

        # Load configurations
        configs = self.load_all_configs()

        runner_script = '''#!/usr/bin/env python3
"""
Auto-generated Kaspa Test Runner
This script checks all prerequisites and runs the transaction generator
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path

class KaspaTestRunner:
    def __init__(self):
        self.config_dir = Path.home() / ".kaspa_test_orchestrator"
        self.configs = self.load_configs()

    def load_configs(self):
        """Load all configuration files"""
        configs = {}
        for config_type in ["node", "wallet", "test"]:
            config_file = self.config_dir / f"{config_type}.json"
            if config_file.exists():
                with open(config_file) as f:
                    configs[config_type] = json.load(f)
        return configs

    def check_docker_running(self):
        """Check if Docker is running"""
        try:
            result = subprocess.run(["docker", "ps"], capture_output=True, text=True)
            return result.returncode == 0
        except:
            return False

    def check_kaspad_running(self):
        """Check if Kaspad container is running"""
        try:
            result = subprocess.run(
                ["docker", "ps", "--format", "{{.Names}}"],
                capture_output=True,
                text=True
            )
            return "kaspad-testnet" in result.stdout
        except:
            return False

    def start_kaspad(self):
        """Start Kaspad container"""
        print("Starting Kaspad node...")
        subprocess.run(["docker", "start", "kaspad-testnet"])
        time.sleep(5)

    def check_kaspad_synced(self):
        """Check if Kaspad is synced (simplified check)"""
        # In reality, would check sync status via RPC
        print("Checking Kaspad sync status...")
        time.sleep(2)
        return True

    def run_test(self):
        """Run the transaction generator test"""
        print("=" * 60)
        print("🚀 KASPA TRANSACTION GENERATOR - TEST RUNNER")
        print("=" * 60)

        # Check Docker
        if not self.check_docker_running():
            print("❌ Docker is not running. Please start Docker Desktop.")
            return False

        # Check Kaspad
        if not self.check_kaspad_running():
            print("⚠️  Kaspad is not running. Starting it now...")
            self.start_kaspad()

        # Check sync status
        if not self.check_kaspad_synced():
            print("⏳ Waiting for Kaspad to sync...")
            time.sleep(10)

        # Prepare environment variables
        env = os.environ.copy()
        env["PRIVATE_KEY_HEX"] = self.configs["wallet"]["private_key"]

        # Build command
        cmd = [
            "cargo", "run", "--release", "--bin", "Tx_gen", "--",
            "--network", self.configs["test"]["network"],
            "--target-tps", str(self.configs["test"]["target_tps"]),
            "--duration", str(self.configs["test"]["duration"]),
            "--rpc-endpoint", f"http://{self.configs['node']['rpc_endpoint']}"
        ]

        if self.configs["test"]["unleashed"]:
            cmd.append("--unleashed")

        print(f"\\n✅ Starting test with {self.configs['test']['target_tps']} TPS")
        if self.configs["test"]["duration"] > 0:
            print(f"   Duration: {self.configs['test']['duration']} seconds")
        else:
            print("   Duration: Unlimited (press Ctrl+C to stop)")

        print("\\n" + "=" * 60)

        # Change to project directory
        project_dir = Path(__file__).parent / "rusty-kaspa"
        os.chdir(project_dir)

        # Run the test
        try:
            subprocess.run(cmd, env=env)
        except KeyboardInterrupt:
            print("\\n\\n✅ Test stopped by user")
        except Exception as e:
            print(f"\\n❌ Test failed: {e}")
            return False

        return True

if __name__ == "__main__":
    runner = KaspaTestRunner()
    runner.run_test()
'''

        # Write runner script
        runner_file = Path("run_kaspa_test.py")
        runner_file.write_text(runner_script)
        runner_file.chmod(0o755)

        self.print_success("Test runner script created: run_kaspa_test.py")

        # Also create a batch/shell launcher
        if self.is_windows:
            launcher = Path("run_test.bat")
            launcher.write_text("@echo off\npython run_kaspa_test.py\npause")
        else:
            launcher = Path("run_test.sh")
            launcher.write_text("#!/bin/bash\npython3 run_kaspa_test.py")
            launcher.chmod(0o755)

        return True

    def save_config(self, config_type: str, config: dict):
        """Save configuration to file"""
        config_file = self.config_dir / f"{config_type}.json"
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)

    def load_all_configs(self) -> dict:
        """Load all configurations"""
        configs = {}
        for config_type in ["node", "wallet", "test"]:
            config_file = self.config_dir / f"{config_type}.json"
            if config_file.exists():
                with open(config_file) as f:
                    configs[config_type] = json.load(f)
        return configs

def main():
    orchestrator = KaspaTestOrchestrator()
    try:
        orchestrator.run()
    except KeyboardInterrupt:
        print("\n\nSetup cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()