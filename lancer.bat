@echo off
REM Compile le jeu puis le lance dans le simulateur Playdate.
setlocal
cd /d "%~dp0"

if "%PLAYDATE_SDK_PATH%"=="" set "PLAYDATE_SDK_PATH=%USERPROFILE%\Documents\PlaydateSDK"

if not exist "%PLAYDATE_SDK_PATH%\bin\pdc.exe" (
    echo [ERREUR] SDK Playdate introuvable dans "%PLAYDATE_SDK_PATH%".
    echo Installez-le depuis https://play.date/dev/ puis relancez ce script.
    pause
    exit /b 1
)

REM Le simulateur sauvegarde dans le dossier Disk du SDK : il doit etre modifiable.
set "TESTFILE=%PLAYDATE_SDK_PATH%\Disk\Data\_test_ecriture.tmp"
(echo test> "%TESTFILE%") 2>nul
if exist "%TESTFILE%" (
    del "%TESTFILE%"
) else (
    echo.
    echo [ATTENTION] Le dossier "%PLAYDATE_SDK_PATH%\Disk" n'est pas modifiable :
    echo les sauvegardes du jeu ne fonctionneront pas dans le simulateur.
    echo Solution : ouvrir un terminal en administrateur et taper :
    echo   icacls "%PLAYDATE_SDK_PATH%\Disk" /grant *S-1-5-32-545:^(OI^)^(CI^)M /T
    echo.
    pause
)

echo Compilation...
"%PLAYDATE_SDK_PATH%\bin\pdc.exe" source Nurikabe.pdx
if errorlevel 1 (
    echo [ERREUR] La compilation a echoue.
    pause
    exit /b 1
)

echo Lancement du simulateur...
start "" "%PLAYDATE_SDK_PATH%\bin\PlaydateSimulator.exe" "%~dp0Nurikabe.pdx"
endlocal
