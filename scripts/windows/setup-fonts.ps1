# scripts/windows/setup-fonts.ps1 — Install Nerd Fonts on Windows

Write-Host "[INFO] Installing Nerd Fonts..." -ForegroundColor Blue

$fontsToInstall = @(
    @{ Name = "Hack"; Url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" },
    @{ Name = "FiraCode"; Url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" }
)

$tempDir = "$env:TEMP\nerd-fonts"
$fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

foreach ($font in $fontsToInstall) {
    $zipPath = "$tempDir\$($font.Name).zip"
    $extractPath = "$tempDir\$($font.Name)"

    # Check if any font from this family is already installed
    $existingFonts = Get-ChildItem $fontsDir -Filter "*$($font.Name)*" -ErrorAction SilentlyContinue
    if ($existingFonts) {
        Write-Host "[WARN] $($font.Name) Nerd Font already installed" -ForegroundColor Yellow
        continue
    }

    Write-Host "[INFO] Downloading $($font.Name) Nerd Font..." -ForegroundColor Blue
    Invoke-WebRequest -Uri $font.Url -OutFile $zipPath

    Write-Host "[INFO] Extracting $($font.Name)..." -ForegroundColor Blue
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Install each .ttf file
    Get-ChildItem "$extractPath\*.ttf" | ForEach-Object {
        $destPath = Join-Path $fontsDir $_.Name
        Copy-Item $_.FullName $destPath -Force

        # Register the font
        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontName = $_.BaseName
        New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $destPath -PropertyType String -Force | Out-Null
    }

    Write-Host "[  OK] $($font.Name) Nerd Font installed" -ForegroundColor Green
}

# Cleanup
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[  OK] Font installation complete" -ForegroundColor Green
