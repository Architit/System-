#requires -version 5.1
#requires -runasadministrator
<#
Autopilot Post-Reset Optimize — ASUS
Назначение: Восстановление после сброса (драйверы, Wi‑Fi, приложения) + базовые оптимизации.
По умолчанию берёт последний бэкап из <Root>\BACKUP\*
#>

[CmdletBinding()]
param(
    [string]$Root = "",
    [string]$BackupPath = ""  # можно явно указать конкретную папку бэкапа
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
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }

# 0) Папки/лог
$Root = Get-AutopilotRoot -Provided $Root
$LogsRoot = Join-Path $Root 'LOGS'
Ensure-Dir $LogsRoot
$TimeStamp = Get-Date -Format 'yyyyMMdd-HHmm'
$LogMain   = Join-Path $LogsRoot ("post_reset_optimize_{0}.log" -f $TimeStamp)
Start-Transcript -Path $LogMain -Append | Out-Null

# 1) Определяем бэкап
if (-not $BackupPath) {
    $bp = Join-Path $Root 'BACKUP'
    if (Test-Path $bp) {
        $latest = Get-ChildItem -Path $bp -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $BackupPath = $latest.FullName }
    }
}
if (-not (Test-Path $BackupPath)) { throw "Не найден бэкап. Укажите -BackupPath или положите бэкап в $Root\BACKUP" }

Write-Host "AUTOPILOT ROOT: $Root"
Write-Host "BACKUP PATH   : $BackupPath"

$DriversDir    = Join-Path $BackupPath 'Drivers'
$WiFiDir       = Join-Path $BackupPath 'WiFi'
$AppListJson   = Join-Path $BackupPath 'AppList\winget-packages.json'

# 2) Восстановление Wi‑Fi профилей
if (Test-Path $WiFiDir) {
    Get-ChildItem -Path $WiFiDir -Filter *.xml | ForEach-Object {
        try { & netsh wlan add profile filename="$_" user=all | Out-Null } catch { Write-Warning "Wi-Fi профиль: $_ — $_" }
    }
}

# 3) Установка драйверов (pnputil)
if (Test-Path $DriversDir) {
    try {
        & pnputil /add-driver "$DriversDir\*.inf" /subdirs /install | Out-Null
    } catch { Write-Warning "Установка драйверов: $_" }
}

# 4) Установка .NET 3.5 (по требованию многих ПО)
try { & DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart | Out-Null } catch { Write-Warning "NetFx3: $_" }

# 5) Импорт приложений (winget)
try {
    if (Test-Path $AppListJson -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        winget source update | Out-Null
        winget import -i "$AppListJson" --accept-source-agreements --accept-package-agreements --disable-interactivity
    } else {
        Write-Warning "winget или JSON не найден — пропуск импорта приложений."
    }
} catch { Write-Warning "Импорт winget: $_" }

# 6) Проводник и базовые преднастройки
try {
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    New-Item -Path $adv -Force | Out-Null
    Set-ItemProperty -Path $adv -Name HideFileExt -Type DWord -Value 0   # показывать расширения
    Set-ItemProperty -Path $adv -Name Hidden      -Type DWord -Value 1   # показывать скрытые файлы
    Set-ItemProperty -Path $adv -Name ShowSuperHidden -Type DWord -Value 0
    Set-ItemProperty -Path $adv -Name LaunchTo    -Type DWord -Value 1   # "Этот компьютер"
    Stop-Process -Name explorer -ErrorAction SilentlyContinue
    Start-Process explorer.exe
} catch { Write-Warning "Настройки проводника: $_" }

# 7) Энергоплан
try { & powercfg /setactive SCHEME_BALANCED | Out-Null } catch { Write-Warning "Энергоплан: $_" }

# 8) Пинок центру обновлений
try { Start-Process -FilePath "$env:WINDIR\System32\UsoClient.exe" -ArgumentList 'StartScan' -NoNewWindow } catch { }

Stop-Transcript | Out-Null
Write-Host "Готово. Базовое восстановление выполнено." -ForegroundColor Green
