@echo off
rem Role audit (docs/ROLES.md): tools\role_audit.bat [-Workers 6] [-Only MOLTRES,ZAPDOS] [-ReportOnly]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0role_audit.ps1" %*
