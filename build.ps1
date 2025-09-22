# PowerShell build script for Windows

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Kaspa TX Generator Build Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Check if setup has been run
if (-not (Test-Path "rusty-kaspa\Tx_gen")) {
    Write-Host "⚠ Setup has not been run. Running setup first..." -ForegroundColor Yellow
    .\setup.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Setup failed" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Sync files to workspace
Write-Host "→ Syncing files to workspace..." -ForegroundColor Yellow
Copy-Item "Cargo.toml" "rusty-kaspa\Tx_gen\" -Force
Copy-Item "src\*" "rusty-kaspa\Tx_gen\src\" -Recurse -Force
Write-Host "✓ Files synced" -ForegroundColor Green

# Build the project
Write-Host "→ Building Tx_gen (this may take a while on first run)..." -ForegroundColor Yellow
Push-Location "rusty-kaspa"

cargo build --release --bin Tx_gen
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "✗ Build failed" -ForegroundColor Red
    exit 1
}

Pop-Location

Write-Host "✓ Build successful!" -ForegroundColor Green
Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Build complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Binary location:" -ForegroundColor Yellow
Write-Host "  rusty-kaspa\target\release\Tx_gen.exe" -ForegroundColor White
Write-Host ""
Write-Host "To run:" -ForegroundColor Yellow
Write-Host "  .\rusty-kaspa\target\release\Tx_gen.exe --help" -ForegroundColor White
Write-Host ""
Write-Host "Example usage:" -ForegroundColor Yellow
Write-Host "  cd rusty-kaspa" -ForegroundColor White
Write-Host "  cargo run --release --bin Tx_gen -- --network testnet10" -ForegroundColor White
Write-Host ""
Write-Host "Or with environment variable:" -ForegroundColor Yellow
Write-Host "  `$env:PRIVATE_KEY_HEX='your_key'; cargo run --release --bin Tx_gen" -ForegroundColor White
Write-Host "===================================" -ForegroundColor Cyan