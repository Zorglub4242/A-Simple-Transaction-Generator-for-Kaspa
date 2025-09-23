# Build Docker image for Kaspa Transaction Generator
param(
    [string]$Tag = "latest",
    [string]$Registry = "zorglub4242",
    [switch]$Push
)

$ImageName = "$Registry/kaspa-tx-generator"
$FullTag = "${ImageName}:${Tag}"

Write-Host "======================================"
Write-Host "Building Kaspa Transaction Generator Docker Image" -ForegroundColor Cyan
Write-Host "======================================"
Write-Host ""
Write-Host "Image: $FullTag" -ForegroundColor White
Write-Host ""

# Build the image
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t $FullTag .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Build successful!" -ForegroundColor Green

# Tag as latest if not already
if ($Tag -ne "latest") {
    Write-Host "Tagging as latest..." -ForegroundColor Yellow
    docker tag $FullTag "${ImageName}:latest"
}

# Get image size
$imageInfo = docker images $FullTag --format "{{.Size}}"
Write-Host ""
Write-Host "Image size: $imageInfo" -ForegroundColor Cyan

# Push if requested
if ($Push) {
    Write-Host ""
    Write-Host "Pushing to Docker Hub..." -ForegroundColor Yellow

    # Push the specific tag
    docker push $FullTag

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed!" -ForegroundColor Red
        exit 1
    }

    # Push latest if applicable
    if ($Tag -ne "latest") {
        docker push "${ImageName}:latest"
    }

    Write-Host "Push successful!" -ForegroundColor Green
    Write-Host "Image available at: https://hub.docker.com/r/$Registry/kaspa-tx-generator" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "To push to Docker Hub, run:" -ForegroundColor Yellow
    Write-Host "  .\build-docker.ps1 -Push" -ForegroundColor White
}

# Show usage examples
Write-Host ""
Write-Host "======================================"
Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Basic run:" -ForegroundColor Yellow
Write-Host "  docker run -e PRIVATE_KEY_HEX=yourkey $FullTag" -ForegroundColor White
Write-Host ""
Write-Host "With custom parameters:" -ForegroundColor Yellow
Write-Host "  docker run \`" -ForegroundColor White
Write-Host "    -e PRIVATE_KEY_HEX=yourkey \`" -ForegroundColor White
Write-Host "    -e TARGET_TPS=100 \`" -ForegroundColor White
Write-Host "    -e TARGET_UTXO_COUNT=200 \`" -ForegroundColor White
Write-Host "    $FullTag" -ForegroundColor White
Write-Host ""
Write-Host "With local kaspad:" -ForegroundColor Yellow
Write-Host "  docker run \`" -ForegroundColor White
Write-Host "    --network host \`" -ForegroundColor White
Write-Host "    -e PRIVATE_KEY_HEX=yourkey \`" -ForegroundColor White
Write-Host "    -e RPC_ENDPOINT=grpc://localhost:16210 \`" -ForegroundColor White
Write-Host "    $FullTag" -ForegroundColor White
Write-Host "======================================"