# Autopilot Watchdog — health loop every 5 minutes
$ErrorActionPreference = "SilentlyContinue"
$Root = "C:\ProgramData\Autopilot"
$Log  = Join-Path $Root "logs\watchdog.log"

function Log($m){ if(!(Test-Path "$Root\logs")){New-Item -ItemType Directory -Path "$Root\logs" -Force | Out-Null}; 
  ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m) | Out-File $Log -Append -Encoding utf8 }

# Basic health checks
$net = Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($net) { Log "Net=OK" } else { Log "Net=DOWN"; }

# Restart update orchestrator if needed
try {
  Set-Service -Name wuauserv -StartupType Automatic
  if ((Get-Service wuauserv).Status -ne "Running") { Start-Service wuauserv; Log "wuauserv restarted." }
} catch {}

# Rotate heartbeat
$hb = Join-Path $Root "logs\heartbeat.txt"
("alive {0}" -f (Get-Date)) | Out-File $hb -Append -Encoding utf8