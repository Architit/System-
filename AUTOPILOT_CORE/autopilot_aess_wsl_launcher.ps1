# Launches AESS bootstrap inside WSL from Windows startup context.
$ErrorActionPreference = "SilentlyContinue"

$Root = "C:\ProgramData\Autopilot"
$LogDir = Join-Path $Root "logs"
$Log = Join-Path $LogDir "aess_wsl_launcher.log"
$WslDistro = if ($env:AESS_WSL_DISTRO) { $env:AESS_WSL_DISTRO } else { "Ubuntu" }
$WslScript = "/mnt/c/ProgramData/Autopilot/aess_bootstrap.sh"

function Write-Log([string]$Message) {
  if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
  }
  ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) | Out-File -FilePath $Log -Append -Encoding utf8
}

Write-Log "AESS WSL launcher start. distro=$WslDistro"

if (!(Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  Write-Log "wsl.exe not found; skip"
  exit 0
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($identity -eq "NT AUTHORITY\SYSTEM") {
  Write-Log "Running as SYSTEM. User-scoped WSL distro is usually unavailable; skip."
  exit 0
}

$cmd = "chmod +x '$WslScript' && '$WslScript'"
$output = & wsl.exe -d $WslDistro -- bash -lc $cmd 2>&1

if ($LASTEXITCODE -eq 0) {
  if ($output) { $output | ForEach-Object { Write-Log "wsl: $_" } }
  Write-Log "AESS bootstrap executed successfully in WSL."
} else {
  if ($output) { $output | ForEach-Object { Write-Log "wsl: $_" } }
  Write-Log "AESS bootstrap failed in WSL. exit_code=$LASTEXITCODE"
}
