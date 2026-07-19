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
#
# Uninstall / clean up:
#     Unregister-ScheduledTask -TaskName Syncthing -Confirm:$false
#     winget uninstall Syncthing.Syncthing

#Requires -Version 5.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# `$PSVersionTable.Platform` was added in PowerShell 6. PowerShell 5.1 is
# Windows-only, so the check is only meaningful on 6+. Guard the property
# access; `Set-StrictMode -Version Latest` makes the missing property fatal
# on 5.1 otherwise.
if ($PSVersionTable.PSVersion.Major -ge 6 -and $PSVersionTable.Platform -eq 'Unix') {
    throw "This script is Windows-only. Detected Platform=$($PSVersionTable.Platform)."
}

$TaskName = 'Syncthing'
$WingetId = 'Syncthing.Syncthing'

# --- 1. Install via winget if missing ---------------------------------------
if (-not (Get-Command syncthing.exe -ErrorAction SilentlyContinue)) {
    Write-Host "🔧 Syncthing not on PATH — installing via winget..."
    winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget install failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host "✅ Syncthing already installed"
}

# --- 2. Resolve syncthing.exe path ------------------------------------------
$syncthingCmd = Get-Command syncthing.exe -ErrorAction SilentlyContinue
if (-not $syncthingCmd) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Syncthing\syncthing.exe",
        "$env:ProgramFiles\Syncthing\syncthing.exe",
        "$env:ProgramFiles(x86)\Syncthing\syncthing.exe"
    )
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) { $syncthingCmd = [PSCustomObject]@{ Source = $found } }
}
if (-not $syncthingCmd) {
    throw "Cannot locate syncthing.exe after install. Check ``winget list Syncthing``."
}
$SyncthingPath = $syncthingCmd.Source
Write-Host "   at: $SyncthingPath"

# --- 3. Register scheduled task at login ------------------------------------
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "✅ Scheduled task '$TaskName' already exists"
} else {
    Write-Host "🔧 Creating scheduled task '$TaskName'..."
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
    Write-Host "✅ Task created"
}

# --- 4. Start it if it isn't already running --------------------------------
$proc = Get-Process syncthing -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "✅ Syncthing already running (PID $($proc.Id))"
} else {
    Write-Host "🔧 Starting task '$TaskName'..."
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 3
    $proc = Get-Process syncthing -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "✅ Syncthing started (PID $($proc.Id))"
    } else {
        Write-Warning "Syncthing didn't appear as a process within 3s. Check Event Viewer → Task Scheduler."
    }
}

# --- 5. Wait for GUI, print device ID ---------------------------------------
Write-Host "⏳ Waiting for GUI on http://localhost:8384 ..."
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
    Write-Host '✅ Syncthing is up.'
    Write-Host ''
    Write-Host "Your device ID:"
    Write-Host "  $deviceId"
    Write-Host ''
    Write-Host 'Next: on cerebros GUI (http://192.168.1.250:8384):'
    Write-Host '  1. Add Remote Device → paste the ID above → name it (e.g. "forge")'
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
