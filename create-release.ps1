# PowerShell script to create release package

$version = "0.2.0"
$releaseName = "kaspa-tx-generator-v$version-windows-x64"

Write-Host "Creating release package: $releaseName.zip" -ForegroundColor Cyan

# Navigate to release directory
Push-Location "release"

# Create the zip file
Compress-Archive -Path "windows-x64\*" -DestinationPath "$releaseName.zip" -Force

# Get file info
$zipInfo = Get-Item "$releaseName.zip"
$sizeInMB = [math]::Round($zipInfo.Length / 1MB, 2)

Pop-Location

Write-Host "Release package created successfully!" -ForegroundColor Green
Write-Host "  File: release\$releaseName.zip" -ForegroundColor White
Write-Host "  Size: $sizeInMB MB" -ForegroundColor White
Write-Host ""
Write-Host "This package includes:" -ForegroundColor Yellow
Write-Host "  - Tx_gen.exe (the main executable)"
Write-Host "  - .env.example (configuration template)"
Write-Host "  - config.example.toml (advanced configuration)"
Write-Host "  - README.txt (instructions)"
Write-Host "  - run-testnet.bat (easy testnet launcher)"
Write-Host "  - run-mainnet.bat (mainnet launcher)"
Write-Host "  - LICENSE"