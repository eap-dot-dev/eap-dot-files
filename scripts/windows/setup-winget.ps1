# scripts/windows/setup-winget.ps1 — Install Windows apps via winget
# Reads winget keys from packages.toml

param(
    [string]$PackagesFile = "$PSScriptRoot\..\..\packages.toml"
)

Write-Host "[INFO] Installing Windows apps via winget..." -ForegroundColor Blue

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[ ERR] winget not found. Please install App Installer from the Microsoft Store." -ForegroundColor Red
    exit 1
}

# Parse packages.toml for winget keys
$content = Get-Content $PackagesFile -Raw
$lines = $content -split "`n"

foreach ($line in $lines) {
    if ($line -match '^\s*winget\s*=\s*"([^"]+)"') {
        $packageId = $Matches[1]

        # Check if already installed
        $installed = winget list --id $packageId 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $packageId) {
            Write-Host "[WARN] Already installed: $packageId" -ForegroundColor Yellow
        } else {
            Write-Host "[INFO] Installing: $packageId" -ForegroundColor Blue
            winget install --id $packageId --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[  OK] Installed: $packageId" -ForegroundColor Green
            } else {
                Write-Host "[ ERR] Failed to install: $packageId" -ForegroundColor Red
            }
        }
    }
}

Write-Host "[  OK] winget installations complete" -ForegroundColor Green
