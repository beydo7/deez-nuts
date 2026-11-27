@echo off
rem ============================================================
rem  Deez Nuts! direkt starten, ohne den Godot-Editor zu oeffnen.
rem
rem  Godot wird in dieser Reihenfolge gesucht:
rem   1. Umgebungsvariable GODOT (voller Pfad zur Godot-exe)
rem   2. Ordner "Godot" neben dem Projektordner  (..\Godot\)
rem   3. Projektordner selbst
rem   4. godot.exe im PATH
rem ============================================================
setlocal
cd /d "%~dp0"

set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE for %%F in ("%~dp0..\Godot\Godot_v4*_win64.exe") do set "GODOT_EXE=%%~fF"
if not defined GODOT_EXE for %%F in ("%~dp0Godot_v4*_win64.exe") do set "GODOT_EXE=%%~fF"
if not defined GODOT_EXE for %%G in (godot.exe) do if not "%%~$PATH:G"=="" set "GODOT_EXE=%%~$PATH:G"

if not defined GODOT_EXE goto :not_found
if not exist "%GODOT_EXE%" goto :not_found

rem Vor jedem Start importieren, damit neue/geaenderte Skripte und Sounds erkannt werden.
echo Projekt wird aktualisiert, bitte kurz warten ...
"%GODOT_EXE%" --headless --path "%CD%" --import >nul 2>&1

if not exist "%CD%\logs" mkdir "%CD%\logs"
if not exist "%CD%\logs\.gdignore" type nul > "%CD%\logs\.gdignore"
start "" "%GODOT_EXE%" --path "%CD%" --log-file "%CD%\logs\letzter_start.log" %*
exit /b 0

:not_found
echo.
echo  Godot 4.7 wurde nicht gefunden.
echo.
echo  Loesung: Godot_v4.7.2-stable_win64.exe in einen Ordner "Godot"
echo  neben den Projektordner legen, z. B.
echo     D:\Games\Deez Nuts\Godot\Godot_v4.7.2-stable_win64.exe
echo     D:\Games\Deez Nuts\deez-nuts\Spiel_starten.bat
echo.
pause
exit /b 1
