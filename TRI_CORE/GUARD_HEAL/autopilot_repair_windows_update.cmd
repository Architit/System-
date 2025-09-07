@echo off
:: Autopilot — Repair Windows Update (ASUS)
:: Требуется запуск от администратора.
setlocal EnableExtensions EnableDelayedExpansion

:: Проверка прав администратора
net session >nul 2>&1
if not %errorlevel%==0 (
  echo Запустите это окно CMD "от имени администратора".
  pause
  exit /b 1
)

echo [1/8] Остановка служб обновления...
net stop wuauserv /y >nul 2>&1
net stop bits >nul 2>&1
net stop cryptsvc >nul 2>&1
net stop msiserver >nul 2>&1

echo [2/8] Очистка кэша обновлений...
takeown /f "%windir%\SoftwareDistribution" /r /d y >nul 2>&1
icacls "%windir%\SoftwareDistribution" /grant administrators:F /T >nul 2>&1
ren "%windir%\SoftwareDistribution" "SoftwareDistribution.bak.%random%" >nul 2>&1

takeown /f "%windir%\System32\catroot2" /r /d y >nul 2>&1
icacls "%windir%\System32\catroot2" /grant administrators:F /T >nul 2>&1
ren "%windir%\System32\catroot2" "catroot2.bak.%random%" >nul 2>&1

echo [3/8] Перерегистрация основных компонентов WU...
for %%i in (
  atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll
  msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll
  gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll
  wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll
  qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll
) do (
  regsvr32 /s %%i
)

echo [4/8] Сброс сети (Winsock)...
netsh winsock reset >nul

echo [5/8] Запуск служб...
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start msiserver >nul 2>&1
net start wuauserv >nul 2>&1

echo [6/8] Проверка целостности и восстановление компонентов (DISM) — это может занять время...
DISM /Online /Cleanup-Image /RestoreHealth

echo [7/8] SFC /Scannow — это может занять время...
SFC /Scannow

echo [8/8] Принудительный поиск обновлений...
if exist "%windir%\System32\UsoClient.exe" ( "%windir%\System32\UsoClient.exe" StartScan )
wuauclt /resetauthorization /detectnow

echo Готово. При необходимости перезагрузите ПК.
pause
exit /b 0
