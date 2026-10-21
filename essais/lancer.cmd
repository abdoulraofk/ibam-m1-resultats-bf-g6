@echo off
rem Lance un script de essais\ avec Git Bash, depuis PowerShell ou cmd.
rem
rem   essais\lancer.cmd controle_socle
rem   essais\lancer.cmd v5_reconstruction
rem   essais\lancer.cmd r2_idempotence bdd1 app1
rem
rem Pourquoi : dans PowerShell, "bash" lance WSL (ou vagrant ne voit pas les
rem VM de Windows), et un double-clic sur .sh ouvre une fenetre qui se ferme
rem aussitot. Les variables NB_APP / EXT definies dans la session sont transmises.
setlocal
set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%GITBASH%" set "GITBASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not exist "%GITBASH%" (
  echo Git Bash introuvable : installer Git for Windows, https://git-scm.com 1>&2
  exit /b 1
)
if "%~1"=="" (
  echo Usage : essais\lancer.cmd ^<controle_socle^|v5_reconstruction^|r2_idempotence^> [arguments] 1>&2
  exit /b 1
)
set "SCRIPT=%~dp0%~1.sh"
if not exist "%SCRIPT%" (
  echo Script introuvable : %SCRIPT% 1>&2
  exit /b 1
)
rem Barres obliques : sous Git Bash, dirname ne comprend pas les antislashs.
set "SCRIPT=%SCRIPT:\=/%"
"%GITBASH%" "%SCRIPT%" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%
