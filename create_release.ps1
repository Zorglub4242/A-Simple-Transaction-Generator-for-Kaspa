# Script to create a clean release package
Write-Host "Creating release package..." -ForegroundColor Cyan

$version = "v0.3.0"
$releaseName = "kaspa-tx-generator-$version"
$tempDir = ".\temp_release"

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}

# Create temp directory structure
New-Item -ItemType Directory -Path $tempDir | Out-Null
New-Item -ItemType Directory -Path "$tempDir\$releaseName" | Out-Null
New-Item -ItemType Directory -Path "$tempDir\$releaseName\rusty-kaspa" | Out-Null

Write-Host "Copying essential files..." -ForegroundColor Gray

# Copy root files
Copy-Item "Start-KaspaTest.ps1" "$tempDir\$releaseName\" -Force
Copy-Item "README.md" "$tempDir\$releaseName\" -Force
Copy-Item "LICENSE" "$tempDir\$releaseName\" -Force
Copy-Item ".env.example" "$tempDir\$releaseName\" -Force
Copy-Item "config.example.toml" "$tempDir\$releaseName\" -Force

# Copy rusty-kaspa source files (exclude target and .git)
Write-Host "Copying rusty-kaspa source files..." -ForegroundColor Gray

# Copy essential rusty-kaspa directories
$sourceDirs = @(
    "cli",
    "components",
    "consensus",
    "core",
    "crypto",
    "daemon",
    "database",
    "grpc",
    "hashes",
    "indexes",
    "math",
    "merkle",
    "mining",
    "muhash",
    "network",
    "notify",
    "p2p",
    "perf-monitor",
    "protocol",
    "rpc",
    "simpa",
    "testing",
    "tx_gen",
    "utils",
    "wallet",
    "wasm"
)

foreach ($dir in $sourceDirs) {
    if (Test-Path "rusty-kaspa\$dir") {
        Write-Host "  Copying $dir..." -ForegroundColor DarkGray
        Copy-Item "rusty-kaspa\$dir" "$tempDir\$releaseName\rusty-kaspa\$dir" -Recurse -Force
    }
}

# Copy rusty-kaspa root files
$rootFiles = @(
    "Cargo.toml",
    "Cargo.lock",
    ".rustfmt.toml",
    "clippy.toml",
    "LICENSE",
    "README.md"
)

foreach ($file in $rootFiles) {
    if (Test-Path "rusty-kaspa\$file") {
        Copy-Item "rusty-kaspa\$file" "$tempDir\$releaseName\rusty-kaspa\" -Force
    }
}

# Create the zip file
Write-Host "Creating zip archive..." -ForegroundColor Cyan
$zipPath = ".\$releaseName.zip"

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path "$tempDir\$releaseName" -DestinationPath $zipPath -CompressionLevel Optimal

# Clean up temp directory
Remove-Item $tempDir -Recurse -Force

# Get file size
$fileSize = (Get-Item $zipPath).Length / 1MB
$fileSizeFormatted = "{0:N2}" -f $fileSize

Write-Host ""
Write-Host "Release package created successfully!" -ForegroundColor Green
Write-Host "File: $zipPath" -ForegroundColor White
Write-Host "Size: $fileSizeFormatted MB" -ForegroundColor White
Write-Host ""
Write-Host "You can now upload this to GitHub releases." -ForegroundColor Cyan