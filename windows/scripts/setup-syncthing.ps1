# Idempotent bootstrap for Syncthing on Windows.
#
# What it does (safely — every step is a no-op if already done):
#   1. Installs Syncthing via winget if it isn't already present
#   2. Resolves the syncthing.exe path
#   3. Creates a scheduled task that runs Syncthing at user login
#      (--no-browser --no-restart), with auto-restart-on-crash and
#      run-on-battery permitted
#   4. Starts the task if Syncthing isn't already running
#   5. Waits for the local GUI to come up, prints your device ID
#
# Run from an ordinary (non-elevated) PowerShell:
#     pwsh windows/scripts/setup-syncthing.ps1
# or from WSL via Windows interop:
#     powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w windows/scripts/setup-syncthing.ps1)"
#
# Uninstall / clean up:
#     Unregister-ScheduledTask -TaskName Syncthing -Confirm:$false
#     winget uninstall Syncthing.Syncthing

#Requires -Version 5.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# PowerShell 5.1 doesn't have $PSVersionTable.Platform (added in PS 6+).
# 5.1 is Windows-only anyway; only check on 6+.
if ($PSVersionTable.PSVersion.Major -ge 6 -and $PSVersionTable.Platform -eq 'Unix') {
    throw "This script is Windows-only. Detected Platform=$($PSVersionTable.Platform)."
}

$TaskName = 'Syncthing'
$WingetId = 'Syncthing.Syncthing'

# --- 1. Install via winget if missing ---------------------------------------
# Use `winget list` for detection (does NOT depend on the current shell's PATH).
$listOut = & winget list --id $WingetId --exact --disable-interactivity 2>&1 | Out-String
$isInstalled = $listOut -match [regex]::Escape($WingetId)

if (-not $isInstalled) {
    Write-Host "[install] Installing Syncthing via winget..."
    & winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    # winget's "benign" exit codes we shouldn't treat as failure:
    #   0             = success
    #   -1978335189   = 0x8A15002B, "no available upgrade found"
    #   -1978335153   = 0x8A15004F, "no applicable update"
    #   -1978335216   = 0x8A150010, "already installed / no-op"
    $benign = @(0, -1978335189, -1978335153, -1978335216)
    if ($LASTEXITCODE -notin $benign) {
        throw "winget install failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host "[ok] Syncthing already installed (via winget)"
}

# --- 2. Resolve syncthing.exe path ------------------------------------------
$candidates = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links\syncthing.exe",
    "$env:LOCALAPPDATA\Programs\Syncthing\syncthing.exe",
    "$env:ProgramFiles\Syncthing\syncthing.exe",
    "$env:ProgramFiles(x86)\Syncthing\syncthing.exe"
)
# WinGet Packages dir uses a versioned suffix; glob it.
$pkgGlob = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\$WingetId*\syncthing.exe" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -First 1
if ($pkgGlob) { $candidates = $candidates + $pkgGlob }

$SyncthingPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $SyncthingPath) {
    # Last resort: shell PATH lookup.
    $onPath = Get-Command syncthing.exe -ErrorAction SilentlyContinue
    if ($onPath) { $SyncthingPath = $onPath.Source }
}
if (-not $SyncthingPath) {
    $searched = ($candidates -join "`n  ")
    throw "Cannot locate syncthing.exe after install. Searched:`n  $searched"
}
Write-Host "[ok] syncthing.exe at: $SyncthingPath"

# --- 3. Register scheduled task at login ------------------------------------
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[ok] Scheduled task '$TaskName' already exists"
} else {
    Write-Host "[create] Scheduled task '$TaskName'..."
    $action = New-ScheduledTaskAction `
        -Execute $SyncthingPath `
        -Argument '--no-browser --no-restart'
    $trigger = New-ScheduledTaskTrigger `
        -AtLogOn `
        -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description 'Runs the Syncthing daemon at user login' | Out-Null
    Write-Host "[ok] Task registered"
}

# --- 4. Start it if it isn't already running --------------------------------
$proc = Get-Process syncthing -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "[ok] Syncthing already running (PID $($proc.Id))"
} else {
    Write-Host "[start] Task '$TaskName'..."
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 3
    $proc = Get-Process syncthing -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "[ok] Syncthing started (PID $($proc.Id))"
    } else {
        Write-Warning "Syncthing didn't appear as a process within 3s. Check Event Viewer -> Task Scheduler."
    }
}

# --- 5. Wait for GUI, print device ID ---------------------------------------
Write-Host "[wait] GUI on http://localhost:8384 ..."
$configPath = "$env:LOCALAPPDATA\Syncthing\config.xml"
$deviceId = $null
for ($i = 0; $i -lt 20; $i++) {
    if (Test-Path $configPath) {
        try {
            $config = [xml](Get-Content $configPath -ErrorAction Stop)
            $apiKey = $config.configuration.gui.apikey
            if ($apiKey) {
                $status = Invoke-RestMethod `
                    -Uri 'http://localhost:8384/rest/system/status' `
                    -Headers @{ 'X-API-Key' = $apiKey } `
                    -TimeoutSec 2 `
                    -ErrorAction Stop
                $deviceId = $status.myID
                break
            }
        } catch {
            # not ready yet — keep waiting
        }
    }
    Start-Sleep -Seconds 1
}

Write-Host ''
if ($deviceId) {
    Write-Host '[done] Syncthing is up.'
    Write-Host ''
    Write-Host 'Your device ID:'
    Write-Host "  $deviceId"
    Write-Host ''
    Write-Host 'Next: on cerebro GUI (http://192.168.1.250:8384):'
    Write-Host '  1. Add Remote Device -> paste the ID above -> name it (e.g. "forge")'
    Write-Host '  2. On the "Share" tab: tick the "Cerebro Sync" folder'
    Write-Host '  3. Save'
    Write-Host '  4. Back on this machine (http://localhost:8384): accept the'
    Write-Host '     "new device wants to connect" popup, then accept the'
    Write-Host '     folder share and pick a local sync directory.'
} else {
    Write-Warning 'GUI did not respond in 20s.'
    Write-Warning 'Check http://localhost:8384 manually, or look at:'
    Write-Warning "  $env:LOCALAPPDATA\Syncthing\syncthing.log"
}
