# Autopilot Boot Protocol — runs at system startup
$ErrorActionPreference = "SilentlyContinue"
$Root = "C:\ProgramData\Autopilot"
$Log  = Join-Path $Root "logs\boot.log"

function Log($m){ if(!(Test-Path "$Root\logs")){New-Item -ItemType Directory -Path "$Root\logs" -Force | Out-Null}; 
  ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m) | Out-File $Log -Append -Encoding utf8 }

function Wait-Network {
  Log "Waiting for network connectivity..."
  $deadline = (Get-Date).AddMinutes(3)
  do {
    $ok = Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $ok) { Start-Sleep -Seconds 3 }
  } while (-not $ok -and (Get-Date) -lt $deadline)
  if ($ok) { Log "Network is up." } else { Log "Network not detected (continuing anyway)." }
}

function Optimize-Services {
  Log "Ensuring core services are running..."
  $services = @("wuauserv","bits","Winmgmt","Dnscache")
  foreach($s in $services){
    try {
      Set-Service -Name $s -StartupType Automatic
      Start-Service -Name $s
      Log "Service $s set to Automatic and started."
    } catch {}
  }
}

function Start-Telemetry {
  $hb = Join-Path $Root "logs\heartbeat.txt"
  ("alive {0}" -f (Get-Date)) | Out-File $hb -Append -Encoding utf8
  Log "Heartbeat written."
}

Wait-Network
Optimize-Services
Start-Telemetry