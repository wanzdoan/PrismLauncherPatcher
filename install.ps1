<#
.SYNOPSIS
    Prism Launcher Universal Offline Patcher - Quick 1-Click Installer
.DESCRIPTION
    Automated one-line installer that fetches the patch engine and applies the offline patch.
#>

[CmdletBinding()]
param(
    [string]$Username
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "     Prism Launcher Universal Offline Patcher (Quick Setup) " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan

$patchScriptUrl = "https://raw.githubusercontent.com/wanzdoan/PrismLauncherPatcher/main/patch.ps1"

# Check if local patch.ps1 exists in current directory or script root
$localPatch = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "patch.ps1"))) {
    $localPatch = Join-Path $PSScriptRoot "patch.ps1"
} elseif (Test-Path ".\patch.ps1") {
    $localPatch = (Resolve-Path ".\patch.ps1").Path
}

if ($localPatch) {
    Write-Host "[*] Executing local patch engine: $localPatch" -ForegroundColor DarkGray
    & $localPatch -Patch
    if ($Username) {
        & $localPatch -AddAccount $Username
    }
} else {
    Write-Host "[*] Downloading latest patch engine from GitHub..." -ForegroundColor Yellow
    try {
        $code = Invoke-RestMethod -Uri $patchScriptUrl -UseBasicParsing
    } catch {
        Write-Host "[ERROR] Failed to download patch.ps1 from GitHub: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host "[*] Applying offline patch..." -ForegroundColor Cyan
    & ([scriptblock]::Create($code)) -Patch
    if ($Username) {
        & ([scriptblock]::Create($code)) -AddAccount $Username
    }
}

Write-Host "`n[+] Setup completed successfully!" -ForegroundColor Green
Write-Host "You can now open Prism Launcher and play with offline accounts without a Microsoft account." -ForegroundColor Gray
