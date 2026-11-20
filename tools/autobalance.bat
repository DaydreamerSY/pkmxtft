@echo off
rem Auto balance loop (docs/BOT.md, Tu can bang): tools\autobalance.bat -Iterations 3 -Runs 100 -Workers 12
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autobalance.ps1" %*
