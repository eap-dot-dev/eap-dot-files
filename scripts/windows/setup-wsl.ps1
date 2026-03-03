# scripts/windows/setup-wsl.ps1 — Install and configure WSL

param(
    [string]$Distribution = "Ubuntu"
)

$StageFile = "$env:USERPROFILE\.dotfiles-setup-stage"

Write-Host "[INFO] Setting up WSL..." -ForegroundColor Blue

# Check if WSL is already installed
$wslInstalled = $false
try {
    $wslOutput = wsl --list --quiet 2>$null
    if ($wslOutput -match $Distribution) {
        $wslInstalled = $true
    }
} catch {}

if ($wslInstalled) {
    Write-Host "[WARN] WSL with $Distribution already installed" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Installing WSL with $Distribution..." -ForegroundColor Blue
    wsl --install --distribution $Distribution

    if ($LASTEXITCODE -ne 0) {
        # Likely needs a reboot
        "wsl-installed" | Out-File $StageFile -Force
        Write-Host "[WARN] Reboot required. After rebooting, run setup.ps1 again to continue." -ForegroundColor Yellow
        exit 0
    }
}

# Clone and run setup inside WSL
$repoPath = "~/Development/eap-dot-files"
Write-Host "[INFO] Checking for dotfiles repo inside WSL..." -ForegroundColor Blue

wsl -d $Distribution -- bash -c "
  if [ ! -d $repoPath ]; then
    mkdir -p ~/Development
    cd ~/Development
    git clone https://github.com/eap-dot-dev/eap-dot-files.git
  fi
"

Write-Host "[INFO] Running setup.sh inside WSL..." -ForegroundColor Blue
wsl -d $Distribution -- bash -c "cd $repoPath && bash setup.sh"

# Clean up stage file if it exists
if (Test-Path $StageFile) {
    Remove-Item $StageFile
}

Write-Host "[  OK] WSL setup complete" -ForegroundColor Green
