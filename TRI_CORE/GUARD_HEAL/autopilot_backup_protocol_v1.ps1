#requires -version 5.1
#requires -runasadministrator
<#
Autopilot Backup Protocol v1 — ASUS
Назначение: Создать полный бэкап перед сбросом Windows.
Вывод: D:\AUTOPILOT\BACKUP\<PCNAME_yyyyMMdd-HHmm>\...
#>

[CmdletBinding()]
param(
    # Корень пакета AUTOPILOT (если не указан — авто-выбор диска D/E/F/G/C)
    [string]$Root = ""
)

$ErrorActionPreference = 'Stop'

function Get-AutopilotRoot {
    param([string]$Provided)
    if ($Provided) { return $Provided }
    foreach ($d in @('D:','E:','F:','G:','C:')) {
        if (Test-Path "$d\") { return (Join-Path "$d\" 'AUTOPILOT') }
    }
    return "C:\AUTOPILOT"
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null }
}

function Run-RoboCopy {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$LogFile
    )
    Ensure-Dir $Destination
    $args = @($Source, $Destination, '/E','/ZB','/R:1','/W:1','/MT:16','/XJ','/NFL','/NDL','/NP',"/LOG:$LogFile")
    & robocopy @args | Out-Null
    $code = $LASTEXITCODE
    if ($code -gt 3) { throw "ROBOCOPY error ($code) при копировании $Source" }
}

# 0) Подготовка путей/папок
$Root = Get-AutopilotRoot -Provided $Root
Ensure-Dir $Root
$TimeStamp  = Get-Date -Format 'yyyyMMdd-HHmm'
$BackupPath = Join-Path $Root ("BACKUP\{0}_{1}" -f $env:COMPUTERNAME, $TimeStamp)

$DriversDir    = Join-Path $BackupPath 'Drivers'
$WiFiDir       = Join-Path $BackupPath 'WiFi'
$RegistryDir   = Join-Path $BackupPath 'Registry'
$AppListDir    = Join-Path $BackupPath 'AppList'
$SystemInfoDir = Join-Path $BackupPath 'SystemInfo'
$UserDataDir   = Join-Path $BackupPath 'UserData'
$KeysDir       = Join-Path $BackupPath 'Keys'
$LogsDir       = Join-Path $BackupPath 'Logs'

$null = New-Item -ItemType Directory -Force -Path $DriversDir,$WiFiDir,$RegistryDir,$AppListDir,$SystemInfoDir,$UserDataDir,$KeysDir,$LogsDir

$LogMain = Join-Path $LogsDir ("backup_{0}.log" -f $TimeStamp)
Start-Transcript -Path $LogMain -Append | Out-Null

Write-Host "AUTOPILOT ROOT: $Root"
Write-Host "BACKUP PATH   : $BackupPath"

# 1) Список приложений (winget + резервный CSV)
try {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget source update | Out-Null
        winget export --include-versions --accept-source-agreements --accept-package-agreements -o (Join-Path $AppListDir 'winget-packages.json')
    } else {
        Write-Warning "winget не найден — пропущен экспорт JSON."
    }
} catch { Write-Warning "Не удалось экспортировать список winget: $_" }

try {
    Get-Package |
      Sort-Object Name |
      Select-Object Name,Version,ProviderName |
      Export-Csv -Encoding UTF8 -NoTypeInformation -Path (Join-Path $AppListDir 'installed_packages.csv')
} catch { Write-Warning "Не удалось сохранить список пакетов (Get-Package): $_" }

try {
    Get-AppxPackage |
      Select-Object Name,PackageFullName,Version |
      Export-Csv -Encoding UTF8 -NoTypeInformation -Path (Join-Path $AppListDir 'installed_store_apps.csv')
} catch { Write-Warning "Не удалось сохранить список Store-приложений: $_" }

# 2) Драйверы
try {
    Write-Host "Экспорт драйверов..."
    Export-WindowsDriver -Online -Destination $DriversDir | Out-Null
} catch { Write-Warning "Export-WindowsDriver не выполнен: $_" }

# 3) Профили Wi‑Fi
try {
    Write-Host "Экспорт Wi-Fi профилей..."
    & netsh wlan export profile key=clear folder="$WiFiDir" > (Join-Path $LogsDir 'netsh_wlan_export.log') 2>&1
} catch { Write-Warning "Экспорт Wi-Fi не выполнен: $_" }

# 4) Реестр (основные ветки)
try { & reg export HKCU\Software (Join-Path $RegistryDir 'HKCU_Software.reg') /y | Out-Null } catch { Write-Warning $_ }
try { & reg export HKLM\SOFTWARE (Join-Path $RegistryDir 'HKLM_SOFTWARE.reg') /y | Out-Null } catch { Write-Warning $_ }
try { & reg export HKLM\SYSTEM   (Join-Path $RegistryDir 'HKLM_SYSTEM.reg') /y   | Out-Null } catch { Write-Warning $_ }

# 5) Ключи/активация
try {
    $sl = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue
    $OEMKey = if ($sl) { $sl.OA3xOriginalProductKey } else { $null }
    $BkpKey = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform' -ErrorAction SilentlyContinue).BackupProductKeyDefault
    [PSCustomObject]@{
        OEM_BIOS_Key     = $OEMKey
        BackupProductKey = $BkpKey
    } | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $KeysDir 'windows_keys.json') -Encoding UTF8

    & cscript.exe //nologo "$env:WINDIR\System32\slmgr.vbs" /dlv | Out-File -FilePath (Join-Path $KeysDir 'slmgr_dlv.txt') -Encoding UTF8
} catch { Write-Warning "Сохранение ключей/активации: $_" }

# 6) Системная информация
try { Start-Process -FilePath msinfo32.exe -ArgumentList ("/nfo `"{0}`"" -f (Join-Path $SystemInfoDir 'system.nfo')) -Wait -NoNewWindow } catch { Write-Warning $_ }
try { & systeminfo | Out-File -FilePath (Join-Path $SystemInfoDir 'systeminfo.txt') -Encoding UTF8 } catch { Write-Warning $_ }
try { & driverquery /v /fo csv > (Join-Path $SystemInfoDir 'driverquery.csv') } catch { Write-Warning $_ }
try { & manage-bde -status > (Join-Path $SystemInfoDir 'bitlocker_status.txt') } catch { Write-Warning $_ }
try { & manage-bde -protectors -get C: > (Join-Path $SystemInfoDir 'bitlocker_protectors_C.txt') } catch { Write-Warning $_ }

# 7) Данные пользователя (избранные папки)
$KnownUserFolders = @('Desktop','Documents','Downloads','Pictures','Videos','Music')
foreach ($f in $KnownUserFolders) {
    $src = Join-Path $env:USERPROFILE $f
    if (Test-Path $src) {
        $dst = Join-Path $UserDataDir $f
        Run-RoboCopy -Source $src -Destination $dst -LogFile (Join-Path $LogsDir ("robocopy_{0}.log" -f $f.ToLower()))
    }
}

# Публичный рабочий стол (ярлыки)
if (Test-Path "C:\Users\Public\Desktop") {
    Run-RoboCopy -Source "C:\Users\Public\Desktop" -Destination (Join-Path $UserDataDir 'Public_Desktop') -LogFile (Join-Path $LogsDir 'robocopy_public_desktop.log')
}

# 8) Манифест
try {
    $size = (Get-ChildItem -Path $BackupPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
    $manifest = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        UserName     = $env:USERNAME
        Timestamp    = $TimeStamp
        BackupPath   = $BackupPath
        Root         = $Root
        UserFolders  = $KnownUserFolders
        SizeBytes    = ($size | ForEach-Object { $_ })  # может быть $null
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $BackupPath 'backup_manifest.json') -Encoding UTF8
} catch { Write-Warning "Не удалось записать манифест: $_" }

Stop-Transcript | Out-Null
Write-Host "Готово. Бэкап: $BackupPath" -ForegroundColor Green
