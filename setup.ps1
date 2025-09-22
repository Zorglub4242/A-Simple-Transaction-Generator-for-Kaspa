# PowerShell setup script for Windows

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Kaspa TX Generator Setup Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Check if rusty-kaspa already exists
if (Test-Path "rusty-kaspa") {
    Write-Host "✓ rusty-kaspa directory already exists" -ForegroundColor Green
} else {
    Write-Host "→ Cloning rusty-kaspa repository..." -ForegroundColor Yellow
    git clone https://github.com/kaspanet/rusty-kaspa.git rusty-kaspa
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to clone rusty-kaspa" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ rusty-kaspa cloned successfully" -ForegroundColor Green
}

# Check if Tx_gen is in workspace
$cargoContent = Get-Content "rusty-kaspa\Cargo.toml" -Raw
if ($cargoContent -match "Tx_gen") {
    Write-Host "✓ Tx_gen already in workspace" -ForegroundColor Green
} else {
    Write-Host "→ Adding Tx_gen to workspace..." -ForegroundColor Yellow
    $lines = Get-Content "rusty-kaspa\Cargo.toml"
    $newLines = @()
    $added = $false

    foreach ($line in $lines) {
        $newLines += $line
        if ($line -match "members = \[" -and -not $added) {
            $newLines += '    "Tx_gen",'
            $added = $true
        }
    }

    $newLines | Set-Content "rusty-kaspa\Cargo.toml"
    Write-Host "✓ Tx_gen added to workspace" -ForegroundColor Green
}

# Create Tx_gen directory in rusty-kaspa
Write-Host "→ Setting up Tx_gen in workspace..." -ForegroundColor Yellow
if (-not (Test-Path "rusty-kaspa\Tx_gen\src")) {
    New-Item -ItemType Directory -Path "rusty-kaspa\Tx_gen\src" -Force | Out-Null
}

# Copy files to workspace
Copy-Item "Cargo.toml" "rusty-kaspa\Tx_gen\" -Force
Copy-Item "src\*" "rusty-kaspa\Tx_gen\src\" -Recurse -Force

Write-Host "✓ Files copied to workspace" -ForegroundColor Green

# Check for .env file
if (Test-Path ".env") {
    Write-Host "✓ .env file found" -ForegroundColor Green
} else {
    if (Test-Path ".env.example") {
        Write-Host ""
        Write-Host "⚠ No .env file found. Please copy .env.example to .env and add your private key:" -ForegroundColor Yellow
        Write-Host "  copy .env.example .env" -ForegroundColor White
        Write-Host "  Then edit .env and set PRIVATE_KEY_HEX" -ForegroundColor White
    }
}

# Check for config.toml
if (Test-Path "config.toml") {
    Write-Host "✓ config.toml found" -ForegroundColor Green
} else {
    if (Test-Path "config.example.toml") {
        Write-Host ""
        Write-Host "ℹ No config.toml found. You can optionally copy config.example.toml:" -ForegroundColor Cyan
        Write-Host "  copy config.example.toml config.toml" -ForegroundColor White
        Write-Host "  Then customize the settings as needed" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Ensure you have a .env file with your PRIVATE_KEY_HEX set"
Write-Host "2. Optionally create config.toml from config.example.toml"
Write-Host "3. Build the project: .\build.ps1"
Write-Host "4. Run the generator:"
Write-Host "   cd rusty-kaspa"
Write-Host "   cargo run --release --bin Tx_gen -- --network testnet10"
Write-Host "===================================" -ForegroundColor Cyan