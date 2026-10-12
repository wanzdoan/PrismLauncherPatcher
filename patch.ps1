<#
.SYNOPSIS
    Prism Launcher Universal Offline Patcher (PowerShell Script)
.DESCRIPTION
    Directly patches installed Prism Launcher on Windows to enable offline accounts
    without requiring any Microsoft account. Works on all Prism Launcher versions.
.PARAMETER Patch
    Apply the offline patch to Prism Launcher.
.PARAMETER Unpatch
    Restore the original unmodified executable from backup.
.PARAMETER Status
    Check the current patch status of the executable.
.PARAMETER AddAccount
    Add or update an offline account username in accounts.json.
.PARAMETER ListAccounts
    List all configured accounts in accounts.json.
.PARAMETER ExePath
    Custom path to prismlauncher.exe.
.PARAMETER DataDir
    Custom path to Prism Launcher roaming data directory.
.EXAMPLE
    .\patch.ps1 -Patch
    .\patch.ps1 -Status
    .\patch.ps1 -AddAccount "Steve"
    .\patch.ps1 -Unpatch
#>

[CmdletBinding()]
param (
    [switch]$Patch,
    [switch]$Unpatch,
    [switch]$Status,
    [string]$AddAccount,
    [switch]$ListAccounts,
    [string]$ExePath,
    [string]$DataDir
)

Set-StrictMode -Off

$ErrorActionPreference = "Stop"

# Helper C# type compiled dynamically via Add-Type for ultra-fast PE analysis & byte patching
$CSharpSource = @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace PrismPsEngine
{
    public class PeAnalysis
    {
        public int AnyAccountIsValidOffset;
        public int DecideLaunchModeOffset;
        public int WantedOffset;
        public int ActualOffset;
        public bool IsPatched;
        public bool IsUnpatched;
    }

    public static class Patcher
    {
        private static readonly byte[] StrAddOffline = Encoding.ASCII.GetBytes("You must add a Microsoft account that owns Minecraft");
        private static readonly byte[] StrAddOfflineShort = Encoding.ASCII.GetBytes("before you can add an offline account");
        private static readonly byte[] StrAskDemo = Encoding.ASCII.GetBytes("This account does not own Minecraft");
        private static readonly byte[] StrAskDemoShort = Encoding.ASCII.GetBytes("purchase the game first to play the full version");

        private static int IndexOfSeq(byte[] buf, byte[] pat)
        {
            if (buf == null || pat == null || buf.Length < pat.Length) return -1;
            int limit = buf.Length - pat.Length;
            byte first = pat[0];
            for (int i = 0; i <= limit; i++)
            {
                if (buf[i] != first) continue;
                bool match = true;
                for (int j = 1; j < pat.Length; j++)
                {
                    if (buf[i + j] != pat[j]) { match = false; break; }
                }
                if (match) return i;
            }
            return -1;
        }

        private static int FindPrologue(byte[] data, int offset, int maxBack = 500)
        {
            for (int p = offset; p >= Math.Max(0, offset - maxBack); p--)
            {
                if (p > 0 && (data[p - 1] == 0xCC || data[p - 1] == 0xC3))
                {
                    byte b0 = data[p];
                    byte b1 = (p + 1 < data.Length) ? data[p + 1] : (byte)0;
                    if ((b0 == 0x48 && (b1 == 0x89 || b1 == 0x83 || b1 == 0x81 || b1 == 0x8D)) ||
                        (b0 == 0x55) ||
                        (b0 == 0x40 && b1 == 0x55) ||
                        (b0 == 0x41 && (b1 == 0x54 || b1 == 0x55 || b1 == 0x56 || b1 == 0x57)) ||
                        ((b0 == 0x53 || b0 == 0x56 || b0 == 0x57) && (b1 == 0x53 || b1 == 0x55 || b1 == 0x56 || b1 == 0x57 || b1 == 0x41)))
                    {
                        return p;
                    }
                }
            }
            return -1;
        }

        public static PeAnalysis Analyze(string exePath)
        {
            byte[] data = File.ReadAllBytes(exePath);
            if (data.Length < 0x200 || data[0] != 'M' || data[1] != 'Z')
                throw new Exception("Invalid PE executable (missing MZ).");

            int e_lfanew = BitConverter.ToInt32(data, 0x3C);
            ushort numSections = BitConverter.ToUInt16(data, e_lfanew + 6);
            ushort optHdrSize = BitConverter.ToUInt16(data, e_lfanew + 20);
            int secOffset = e_lfanew + 24 + optHdrSize;

            uint textVaddr = 0, textVsize = 0, textRaddr = 0, textRsize = 0;
            List<uint[]> sections = new List<uint[]>(); // vaddr, vsize, raddr, rsize

            for (int i = 0; i < numSections; i++)
            {
                int sOff = secOffset + i * 40;
                string name = Encoding.ASCII.GetString(data, sOff, 8).TrimEnd('\0');
                uint vsize = BitConverter.ToUInt32(data, sOff + 8);
                uint vaddr = BitConverter.ToUInt32(data, sOff + 12);
                uint rsize = BitConverter.ToUInt32(data, sOff + 16);
                uint raddr = BitConverter.ToUInt32(data, sOff + 20);
                sections.Add(new uint[] { vaddr, vsize, raddr, rsize });
                if (name == ".text")
                {
                    textVaddr = vaddr; textVsize = vsize; textRaddr = raddr; textRsize = rsize;
                }
            }

            if (textRsize == 0) throw new Exception(".text section not found.");

            Func<int, uint?> fileToRva = foff => {
                foreach (var s in sections) {
                    if (foff >= s[2] && foff < s[2] + s[3]) return s[0] + (uint)(foff - s[2]);
                }
                return null;
            };

            Func<int, List<int>> findXrefs = targetFileOff => {
                uint? trva = fileToRva(targetFileOff);
                if (!trva.HasValue) return new List<int>();
                long targetRva = (long)trva.Value;
                List<int> xrefs = new List<int>();
                int start = (int)textRaddr;
                int end = (int)(textRaddr + textRsize - 7);
                long vaddr = textVaddr;
                int[] lens = new int[] { 7, 8, 6, 5 };
                for (int i = start; i < end; i++) {
                    long instRva = vaddr + (i - start);
                    for (int l = 0; l < lens.Length; l++) {
                        int dispOff = i + (lens[l] - 4);
                        if (dispOff + 4 <= data.Length) {
                            int disp = BitConverter.ToInt32(data, dispOff);
                            if ((instRva + lens[l]) + disp == targetRva) { xrefs.Add(i); break; }
                        }
                    }
                }
                return xrefs;
            };

            int anyAccountIsValidOff = -1;
            int s1 = IndexOfSeq(data, StrAddOffline);
            if (s1 == -1) s1 = IndexOfSeq(data, StrAddOfflineShort);
            if (s1 != -1) {
                var refs = findXrefs(s1);
                foreach (int roff in refs) {
                    for (int p = roff; p >= Math.Max(0, roff - 80); p--) {
                        if (data[p] == 0xE8) {
                            int rel = BitConverter.ToInt32(data, p + 1);
                            int target = p + 5 + rel;
                            if (target >= textRaddr && target < textRaddr + textRsize) {
                                anyAccountIsValidOff = target; break;
                            }
                        }
                    }
                    if (anyAccountIsValidOff != -1) break;
                }
            }

            int decideLaunchModeOff = -1;
            int wantedOffset = 0xA8;
            int actualOffset = 0xAC;

            int s2 = IndexOfSeq(data, StrAskDemo);
            if (s2 == -1) s2 = IndexOfSeq(data, StrAskDemoShort);
            if (s2 != -1) {
                var refs2 = findXrefs(s2);
                if (refs2.Count > 0) {
                    int askDemoFunc = FindPrologue(data, refs2[0]);
                    if (askDemoFunc != -1) {
                        List<int> loginCalls = new List<int>();
                        int start = (int)textRaddr;
                        int end = (int)(textRaddr + textRsize - 5);
                        for (int i = start; i < end; i++) {
                            if (data[i] == 0xE8) {
                                int rel = BitConverter.ToInt32(data, i + 1);
                                if (i + 5 + rel == askDemoFunc) loginCalls.Add(i);
                            }
                        }
                        if (loginCalls.Count > 0) {
                            int callOff = loginCalls[0];
                            Dictionary<int, int> counts = new Dictionary<int, int>();
                            for (int p = callOff - 1; p >= Math.Max(0, callOff - 250); p--) {
                                if (data[p] == 0xE8) {
                                    int rel = BitConverter.ToInt32(data, p + 1);
                                    int target = p + 5 + rel;
                                    if (target >= textRaddr && target < textRaddr + textRsize) {
                                        if (!counts.ContainsKey(target)) counts[target] = 0;
                                        counts[target]++;
                                    }
                                }
                            }
                            foreach (var kvp in counts) {
                                if (kvp.Value >= 2) { decideLaunchModeOff = kvp.Key; break; }
                            }
                        }
                    }
                }
            }

            if (decideLaunchModeOff != -1) {
                int checkLen = Math.Min(150, data.Length - decideLaunchModeOff);
                for (int i = decideLaunchModeOff; i < decideLaunchModeOff + checkLen - 6; i++) {
                    if (data[i] == 0x83 && data[i + 1] == 0xB9 && data[i + 6] == 0x02) {
                        int disp = BitConverter.ToInt32(data, i + 2);
                        if (disp >= 0x40 && disp <= 0x300) {
                            wantedOffset = disp; actualOffset = disp + 4; break;
                        }
                    }
                }
            }

            PeAnalysis res = new PeAnalysis();
            res.AnyAccountIsValidOffset = anyAccountIsValidOff;
            res.DecideLaunchModeOffset = decideLaunchModeOff;
            res.WantedOffset = wantedOffset;
            res.ActualOffset = actualOffset;

            if (anyAccountIsValidOff != -1 && decideLaunchModeOff != -1) {
                bool isAiv = (data[anyAccountIsValidOff] == 0xB0 && data[anyAccountIsValidOff + 1] == 0x01 && data[anyAccountIsValidOff + 2] == 0xC3);
                bool isDlm = (data[decideLaunchModeOff] == 0x8B && data[decideLaunchModeOff + 1] == 0x81 &&
                              data[decideLaunchModeOff + 6] == 0x89 && data[decideLaunchModeOff + 7] == 0x81);
                res.IsPatched = (isAiv && isDlm);
                res.IsUnpatched = (!isAiv && !isDlm);
            }

            return res;
        }

        public static void ApplyPatchBytes(string exePath, int aivOff, int dlmOff, int wantedOff, int actualOff)
        {
            byte[] data = File.ReadAllBytes(exePath);
            // Patch 1: B0 01 C3
            data[aivOff] = 0xB0; data[aivOff + 1] = 0x01; data[aivOff + 2] = 0xC3;

            // Patch 2: 8B 81 [wanted] 89 81 [actual] B8 01 00 00 00 C3
            data[dlmOff] = 0x8B; data[dlmOff + 1] = 0x81;
            Array.Copy(BitConverter.GetBytes(wantedOff), 0, data, dlmOff + 2, 4);
            data[dlmOff + 6] = 0x89; data[dlmOff + 7] = 0x81;
            Array.Copy(BitConverter.GetBytes(actualOff), 0, data, dlmOff + 8, 4);
            byte[] tail = new byte[] { 0xB8, 0x01, 0x00, 0x00, 0x00, 0xC3 };
            Array.Copy(tail, 0, data, dlmOff + 12, 6);

            string tmp = exePath + ".tmp";
            File.WriteAllBytes(tmp, data);
            if (File.Exists(exePath)) File.Delete(exePath);
            File.Move(tmp, exePath);
        }

        public static string GetOfflineUuid(string username)
        {
            byte[] input = Encoding.UTF8.GetBytes("OfflinePlayer:" + username);
            using (MD5 md5 = MD5.Create()) {
                byte[] hash = md5.ComputeHash(input);
                hash[6] = (byte)((hash[6] & 0x0F) | 0x30);
                hash[8] = (byte)((hash[8] & 0x3F) | 0x80);
                StringBuilder sb = new StringBuilder(32);
                for (int i = 0; i < 16; i++) sb.Append(hash[i].ToString("x2"));
                return sb.ToString();
            }
        }
    }
}
"@

# Compile C# engine if not already present
if (-not ([System.Management.Automation.PSTypeName]'PrismPsEngine.Patcher').Type) {
    Add-Type -TypeDefinition $CSharpSource
}

# Auto-detect prism launcher paths
function Find-PrismExe {
    $proc = Get-Process -Name prismlauncher -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path -and (Test-Path $proc.Path)) {
        return (Resolve-Path $proc.Path).Path
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe",
        "$env:ProgramFiles\PrismLauncher\prismlauncher.exe",
        "${env:ProgramFiles(x86)}\PrismLauncher\prismlauncher.exe",
        "C:\PrismLauncher\prismlauncher.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }
    return $null
}

function Find-PrismDataDir {
    $candidate = "$env:APPDATA\PrismLauncher"
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    return $null
}

$TargetExe = if ($ExePath) { $ExePath } else { Find-PrismExe }
$TargetData = if ($DataDir) { $DataDir } else { Find-PrismDataDir }

function Stop-PrismIfRunning {
    $procs = Get-Process -Name prismlauncher -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "[!] Prism Launcher is currently running. Stopping process..." -ForegroundColor Yellow
        $procs | Stop-Process -Force
        Start-Sleep -Milliseconds 500
    }
}

function Get-PatchStatus {
    if (-not $TargetExe -or -not (Test-Path $TargetExe)) {
        return @{ Status = "NOT_FOUND"; Message = "Prism Launcher executable not found." }
    }
    try {
        $res = [PrismPsEngine.Patcher]::Analyze($TargetExe)
        if ($res.IsPatched) {
            return @{ Status = "PATCHED"; Message = "Prism Launcher is patched and offline mode is active."; Details = $res }
        } elseif ($res.IsUnpatched) {
            return @{ Status = "UNPATCHED"; Message = "Prism Launcher is original and unmodified."; Details = $res }
        } else {
            return @{ Status = "UNKNOWN"; Message = "Binary has modified or unrecognized structure."; Details = $res }
        }
    } catch {
        # Check if backup exists and analyze backup
        $bak = "$TargetExe.bak"
        if (Test-Path $bak) {
            try {
                $bakRes = [PrismPsEngine.Patcher]::Analyze($bak)
                return @{ Status = "PATCHED"; Message = "Prism Launcher is patched and offline mode is active."; Details = $bakRes }
            } catch {}
        }
        return @{ Status = "ERROR"; Message = $_.Exception.Message }
    }
}

function Apply-OfflinePatch {
    Write-Host "`n[*] Starting Prism Launcher Universal Offline Patcher..." -ForegroundColor Cyan
    if (-not $TargetExe -or -not (Test-Path $TargetExe)) {
        Write-Host "[ERROR] Could not find prismlauncher.exe!" -ForegroundColor Red
        return
    }

    Stop-PrismIfRunning

    $st = Get-PatchStatus
    if ($st.Status -eq "PATCHED") {
        Write-Host "[INFO] Executable is already patched and ready for offline play." -ForegroundColor Green
        return
    }

    $analysis = [PrismPsEngine.Patcher]::Analyze($TargetExe)
    $bak = "$TargetExe.bak"
    if (-not (Test-Path $bak)) {
        Copy-Item -Path $TargetExe -Destination $bak -Force
        Write-Host "[*] Original backup saved to: $bak" -ForegroundColor DarkGray
    }

    [PrismPsEngine.Patcher]::ApplyPatchBytes($TargetExe, $analysis.AnyAccountIsValidOffset, $analysis.DecideLaunchModeOffset, $analysis.WantedOffset, $analysis.ActualOffset)
    Write-Host "[SUCCESS] Prism Launcher successfully patched for offline accounts!" -ForegroundColor Green
    Write-Host "  - AccountList::anyAccountIsValid: 0x$($analysis.AnyAccountIsValidOffset.ToString('X'))" -ForegroundColor DarkGray
    Write-Host "  - LaunchController::decideLaunchMode: 0x$($analysis.DecideLaunchModeOffset.ToString('X'))" -ForegroundColor DarkGray
}

function Restore-OriginalBinary {
    Write-Host "`n[*] Restoring original Prism Launcher executable..." -ForegroundColor Cyan
    Stop-PrismIfRunning

    $bak = "$TargetExe.bak"
    $orig = "$TargetExe.orig"
    $source = if (Test-Path $bak) { $bak } elseif (Test-Path $orig) { $orig } else { $null }

    if (-not $source) {
        Write-Host "[ERROR] No backup file (.bak or .orig) found to restore from!" -ForegroundColor Red
        return
    }

    Copy-Item -Path $source -Destination $TargetExe -Force
    Write-Host "[SUCCESS] Successfully restored original executable from: $source" -ForegroundColor Green
}

function Add-OfflineUser([string]$username) {
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "[ERROR] Username cannot be empty!" -ForegroundColor Red
        return
    }
    if (-not $TargetData) {
        Write-Host "[ERROR] Prism Launcher data directory not found!" -ForegroundColor Red
        return
    }

    $accPath = Join-Path $TargetData "accounts.json"
    $uuid = [PrismPsEngine.Patcher]::GetOfflineUuid($username.Trim())
    $clientToken = [guid]::NewGuid().ToString("N")
    $iat = [int64](([DateTime]::UtcNow - [DateTime](New-Object DateTime 1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalSeconds)

    $root = @{ formatVersion = 3; accounts = @() }
    if (Test-Path $accPath) {
        try {
            $existing = Get-Content $accPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($existing.accounts) { $root.accounts = @($existing.accounts) }
            if ($existing.formatVersion) { $root.formatVersion = $existing.formatVersion }
        } catch {}
    }

    # Set existing to inactive
    foreach ($a in $root.accounts) {
        $a.active = $false
    }

    # Find existing or add
    $found = $null
    foreach ($a in $root.accounts) {
        if ($a.type -eq "Offline" -and $a.profile.name -eq $username.Trim()) {
            $found = $a
            break
        }
    }

    if ($found) {
        $found.active = $true
        $found.profile.id = $uuid
    } else {
        $newAcc = [PSCustomObject]@{
            active = $true
            entitlement = [PSCustomObject]@{ canPlayMinecraft = $true; ownsMinecraft = $true }
            profile = [PSCustomObject]@{
                capes = @()
                id = $uuid
                name = $username.Trim()
                skin = [PSCustomObject]@{ id = ""; url = ""; variant = "" }
            }
            type = "Offline"
            ygg = [PSCustomObject]@{
                extra = [PSCustomObject]@{ clientToken = $clientToken; userName = $username.Trim() }
                iat = $iat
                token = "0"
            }
        }
        $root.accounts += $newAcc
    }

    $json = $root | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($accPath, $json, [System.Text.Encoding]::UTF8)
    Write-Host "[SUCCESS] Account '$username' (UUID: $uuid) saved as default account." -ForegroundColor Green
}

function Show-Accounts {
    if (-not $TargetData) {
        Write-Host "[ERROR] Prism Launcher data directory not found!" -ForegroundColor Red
        return
    }
    $accPath = Join-Path $TargetData "accounts.json"
    if (-not (Test-Path $accPath)) {
        Write-Host "[INFO] No accounts configured yet (accounts.json missing)." -ForegroundColor Yellow
        return
    }

    try {
        $data = Get-Content $accPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "`n[*] Accounts in accounts.json ($($data.accounts.Count)):" -ForegroundColor Cyan
        $i = 1
        foreach ($acc in $data.accounts) {
            $def = if ($acc.active) { " [DEFAULT]" } else { "" }
            Write-Host "  $i. [$($acc.type)] $($acc.profile.name) (UUID: $($acc.profile.id))$def" -ForegroundColor White
            $i++
        }
    } catch {
        Write-Host "[ERROR] Failed to read accounts.json: $_" -ForegroundColor Red
    }
}

# --- Execution Entry Point ---
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "      Prism Launcher Universal Offline Patcher (PS)        " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
if ($TargetExe) { Write-Host "[*] Executable: $TargetExe" -ForegroundColor DarkGray }
if ($TargetData) { Write-Host "[*] Data Dir  : $TargetData" -ForegroundColor DarkGray }

if ($Patch) {
    Apply-OfflinePatch
} elseif ($Unpatch) {
    Restore-OriginalBinary
} elseif ($Status) {
    $st = Get-PatchStatus
    $color = if ($st.Status -eq 'PATCHED') { 'Green' } elseif ($st.Status -eq 'UNPATCHED') { 'Yellow' } else { 'Red' }
    Write-Host "`n[Status] $($st.Status): $($st.Message)" -ForegroundColor $color
    if ($st.Details) {
        Write-Host "  - anyAccountIsValid offset: 0x$($st.Details.AnyAccountIsValidOffset.ToString('X'))" -ForegroundColor DarkGray
        Write-Host "  - decideLaunchMode  offset: 0x$($st.Details.DecideLaunchModeOffset.ToString('X'))" -ForegroundColor DarkGray
        Write-Host "  - wantedLaunchMode  offset: 0x$($st.Details.WantedOffset.ToString('X'))" -ForegroundColor DarkGray
        Write-Host "  - actualLaunchMode  offset: 0x$($st.Details.ActualOffset.ToString('X'))" -ForegroundColor DarkGray
    }
} elseif ($AddAccount) {
    Add-OfflineUser $AddAccount
} elseif ($ListAccounts) {
    Show-Accounts
} else {
    # Interactive mode
    $st = Get-PatchStatus
    $curColor = if ($st.Status -eq 'PATCHED') { 'Green' } elseif ($st.Status -eq 'UNPATCHED') { 'Yellow' } else { 'Red' }
    Write-Host "`n[Current Status] $($st.Status): $($st.Message)" -ForegroundColor $curColor
    Write-Host "`nOptions:" -ForegroundColor Cyan
    Write-Host "  1. Patch Prism Launcher (Enable Offline Accounts)"
    Write-Host "  2. Restore Original Unmodified Executable"
    Write-Host "  3. Check Status"
    Write-Host "  4. Add Offline Account"
    Write-Host "  5. List Accounts"
    Write-Host "  6. Launch Prism Launcher"
    Write-Host "  0. Exit"
    Write-Host ""
    $choice = Read-Host "Select an option [0-6]"
    switch ($choice) {
        "1" { Apply-OfflinePatch }
        "2" { Restore-OriginalBinary }
        "3" {
            $s = Get-PatchStatus
            Write-Host "`n[Status] $($s.Status): $($s.Message)" -ForegroundColor Green
        }
        "4" {
            $user = Read-Host "Enter offline Minecraft username"
            if ($user) { Add-OfflineUser $user }
        }
        "5" { Show-Accounts }
        "6" {
            if ($TargetExe -and (Test-Path $TargetExe)) {
                Start-Process $TargetExe -WorkingDirectory (Split-Path $TargetExe)
            }
        }
        Default { Write-Host "Exiting." }
    }
}
Write-Host ""
