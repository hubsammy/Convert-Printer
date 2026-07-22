# Convert Printer - Font Setup
# Run this script once to copy Chinese fonts from Windows system

$fontsDir = ".\assets\fonts"
if (!(Test-Path $fontsDir)) { New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null }

$fonts = @{
    "simhei.ttf"  = "C:\Windows\Fonts\simhei.ttf"
    "simkai.ttf"  = "C:\Windows\Fonts\simkai.ttf"
    "simfang.ttf" = "C:\Windows\Fonts\simfang.ttf"
    "STSONG.TTF"  = "C:\Windows\Fonts\STSONG.TTF"
}

$missing = @()
foreach ($name in $fonts.Keys) {
    $src = $fonts[$name]
    $dst = Join-Path $fontsDir $name
    if (Test-Path $dst) {
        Write-Host "[OK] $name (exists)"
    } elseif (Test-Path $src) {
        Copy-Item $src $dst -Force
        $size = [math]::Round((Get-Item $dst).Length / 1MB, 1)
        Write-Host "[COPY] $name ($size MB)"
    } else {
        $missing += $name
        Write-Host "[MISSING] $name - not found on system"
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing fonts: $($missing -join ', ')"
    Write-Host "You can download them from:"
    Write-Host "  simhei.ttf:  https://github.com/notofonts/noto-cjk"
    Write-Host "  simkai.ttf:  https://github.com/notofonts/noto-cjk"
    Write-Host "  simfang.ttf: https://github.com/notofonts/noto-cjk"
    Write-Host "  STSONG.TTF:  https://github.com/notofonts/noto-cjk"
}

Write-Host ""
Write-Host "Font setup complete. You can now build the project."
