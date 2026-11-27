@echo off
REM Laedt das Projekt beim ersten Mal auf GitHub hoch (beydo7/deez-nuts).
cd /d "%~dp0"
where git >nul 2>nul || (echo Git ist nicht installiert: https://git-scm.com/download/win & pause & exit /b 1)
git push -u origin main
echo.
echo Fertig. Diese Datei kann danach geloescht werden.
pause
