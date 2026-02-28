# setup.ps1 — Windows native entry point
# Installs Windows apps, fonts, and sets up WSL.

param(
    [switch]$SkipWSL,
    [switch]$SkipWinget,
    [switch]$SkipFonts
)

$ErrorActionPreference = "Stop"
$RepoDir = $PSScriptRoot

Write-Host ""
Write-Host "[INFO] === eap-dot-files Windows setup ===" -ForegroundColor Blue
Write-Host ""

# Check for admin rights (needed for WSL install)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SkipWSL) {
    Write-Host "[WARN] Not running as Administrator. WSL installation requires admin rights." -ForegroundColor Yellow
    Write-Host "[INFO] Re-launching as Administrator..." -ForegroundColor Blue
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit 0
}

# Step 1: winget packages
if (-not $SkipWinget) {
    & "$RepoDir\scripts\windows\setup-winget.ps1" -PackagesFile "$RepoDir\packages.toml"
}

# Step 2: Fonts
if (-not $SkipFonts) {
    & "$RepoDir\scripts\windows\setup-fonts.ps1"
}

# Step 3: WSL
if (-not $SkipWSL) {
    & "$RepoDir\scripts\windows\setup-wsl.ps1"
}

Write-Host ""
Write-Host "[  OK] === Windows setup complete! ===" -ForegroundColor Green
