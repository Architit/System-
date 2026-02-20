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
$AessLauncher   = Join-Path $AutopilotRoot "autopilot_aess_wsl_launcher.ps1"
$AessBootstrap  = Join-Path $AutopilotRoot "aess_bootstrap.sh"
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

  $watchCmd = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$WatchdogScript`""
  schtasks.exe /Create /TN "Autopilot-Watchdog" /SC MINUTE /MO 5 /RU "SYSTEM" /RL HIGHEST /TR $watchCmd /F | Out-Null

  # WSL distros are user-scoped; run AESS launcher at user logon.
  $currentUser = "$env:USERDOMAIN\$env:USERNAME"
  $principalAess = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest
  $actionAess = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$AessLauncher`""
  $triggerAess = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
  $settingsAess = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName "Autopilot-AESS-Logon" -Action $actionAess -Trigger $triggerAess -Settings $settingsAess -Principal $principalAess -Force | Out-Null

  Write-Log "Scheduled tasks registered: Autopilot-Boot, Autopilot-Watchdog, Autopilot-AESS-Logon"
}

function Install-Core {
  Write-Log "Installing Autopilot Core to $AutopilotRoot"
  New-Item -ItemType Directory -Path $AutopilotRoot -Force | Out-Null

  # Copy companion scripts bundled next to this init script.
  # $MyInvocation.MyCommand.Path may be null in nested function scope;
  # prefer $PSScriptRoot and fallback to current directory.
  $here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  Copy-Item (Join-Path $here "autopilot_boot_protocol.ps1") $BootScript -Force
  Copy-Item (Join-Path $here "autopilot_watchdog.ps1") $WatchdogScript -Force
  Copy-Item (Join-Path $here "autopilot_aess_wsl_launcher.ps1") $AessLauncher -Force
  Copy-Item (Join-Path $here "aess_bootstrap.sh") $AessBootstrap -Force

  Ensure-Registry
  Ensure-Tasks
  Write-Log "Installation complete."
}

function Uninstall-Core {
  Write-Log "Removing Scheduled Tasks and files..."
  Get-ScheduledTask -TaskName "Autopilot-Boot","Autopilot-Watchdog","Autopilot-AESS-Logon" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
  if (Test-Path $AutopilotRoot) { Remove-Item $AutopilotRoot -Recurse -Force -ErrorAction SilentlyContinue }
  Write-Log "Uninstall complete."
}

if ($Install) { Install-Core; exit 0 }
if ($Uninstall) { Uninstall-Core; exit 0 }

Write-Host "Usage: .\autopilot_core_init.ps1 -Install  (or -Uninstall)"
