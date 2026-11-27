@echo off
rem Oeffnet das Projekt im Godot-Editor (sucht Godot wie Spiel_starten.bat).
setlocal
cd /d "%~dp0"
set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE for %%F in ("%~dp0..\Godot\Godot_v4*_win64.exe") do set "GODOT_EXE=%%~fF"
if not defined GODOT_EXE for %%G in (godot.exe) do if not "%%~$PATH:G"=="" set "GODOT_EXE=%%~$PATH:G"
if not defined GODOT_EXE (
  echo Godot 4.7 wurde nicht gefunden. Siehe Spiel_starten.bat.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%CD%" --editor
