@echo off
rem Laesst den automatischen Selbsttest laufen (ohne Fenster) und zeigt das Ergebnis.
rem Der echte Spielstand wird dabei nicht angefasst.
setlocal
cd /d "%~dp0"
set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE for %%F in ("%~dp0..\Godot\Godot_v4*_win64.exe") do set "GODOT_EXE=%%~fF"
if not defined GODOT_EXE (
  echo Godot 4.7 wurde nicht gefunden. Siehe Spiel_starten.bat.
  pause
  exit /b 1
)
"%GODOT_EXE%" --headless --path "%CD%" --import >nul 2>&1
"%GODOT_EXE%" --headless --path "%CD%" -- --selbsttest
echo.
if errorlevel 1 (echo SELBSTTEST MIT FEHLERN) else (echo SELBSTTEST OK)
pause
