<# 
Autopilot Core Init
Run in PowerShell (Admin):
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\autopilot_core_init.ps1 -Install

Parameters:
  -Install   -> copies files to C:\ProgramData\Autopilot and registers Scheduled Tasks
  -Uninstall -> removes Scheduled Tasks and files
#>

param(
  [switch]$Install,
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$AutopilotRoot = "C:\ProgramData\Autopilot"
$BootScript     = Join-Path $AutopilotRoot "autopilot_boot_protocol.ps1"
$WatchdogScript = Join-Path $AutopilotRoot "autopilot_watchdog.ps1"
$LogDir         = Join-Path $AutopilotRoot "logs"
$LogFile        = Join-Path $LogDir "autopilot_init.log"

function Write-Log($msg) {
  if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
  ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Ensure-Registry {
  Write-Log "Applying core registry policies (network-first boot, updates, power)..."
  # Always wait for network at startup/logon
  New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "SyncForegroundPolicy" -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "GpNetworkStartTimeoutPolicyValue" -Value 60 -PropertyType DWord -Force | Out-Null

  # Configure Windows Update – Auto download & schedule install at 03:00
  New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 0 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AlwaysAutoRebootAtScheduledTime" -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "ScheduledInstallDay" -Value 0 -PropertyType DWord -Force | Out-Null  # Every day
  New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "ScheduledInstallTime" -Value 3 -PropertyType DWord -Force | Out-Null  # 03:00

  # Power: prevent sleep on AC (OS handles DC separately)
  Start-Process -FilePath "powercfg.exe" -ArgumentList "/x standby-timeout-ac 0" -WindowStyle Hidden -Wait
  Start-Process -FilePath "powercfg.exe" -ArgumentList "/x hibernate-timeout-ac 0" -WindowStyle Hidden -Wait
}

function Ensure-Tasks {
  Write-Log "Registering Scheduled Tasks..."

  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $actionBoot = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$BootScript`""
  $triggerBoot = New-ScheduledTaskTrigger -AtStartup
  $settingsBoot = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -WakeToRun -MultipleInstances IgnoreNew

  Register-ScheduledTask -TaskName "Autopilot-Boot" -Action $actionBoot -Trigger $triggerBoot -Settings $settingsBoot -Principal $principal -Force | Out-Null

  $actionWatch = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$WatchdogScript`""
  $triggerWatch = New-ScheduledTaskTrigger -Once (Get-Date).AddMinutes(1)
  $triggerWatch.Repetition = (New-Object System.Management.Automation.PSObject -Property @{ Interval = (New-TimeSpan -Minutes 5); Duration = ([TimeSpan]::MaxValue) })
  $settingsWatch = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -MultipleInstances IgnoreNew

  Register-ScheduledTask -TaskName "Autopilot-Watchdog" -Action $actionWatch -Trigger $triggerWatch -Settings $settingsWatch -Principal $principal -Force | Out-Null
}

function Install-Core {
  Write-Log "Installing Autopilot Core to $AutopilotRoot"
  New-Item -ItemType Directory -Path $AutopilotRoot -Force | Out-Null

  # Copy companion scripts bundled next to this init script
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  Copy-Item (Join-Path $here "autopilot_boot_protocol.ps1") $BootScript -Force
  Copy-Item (Join-Path $here "autopilot_watchdog.ps1") $WatchdogScript -Force

  Ensure-Registry
  Ensure-Tasks
  Write-Log "Installation complete."
}

function Uninstall-Core {
  Write-Log "Removing Scheduled Tasks and files..."
  Get-ScheduledTask -TaskName "Autopilot-Boot","Autopilot-Watchdog" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
  if (Test-Path $AutopilotRoot) { Remove-Item $AutopilotRoot -Recurse -Force -ErrorAction SilentlyContinue }
  Write-Log "Uninstall complete."
}

if ($Install) { Install-Core; exit 0 }
if ($Uninstall) { Uninstall-Core; exit 0 }

Write-Host "Usage: .\autopilot_core_init.ps1 -Install  (or -Uninstall)"