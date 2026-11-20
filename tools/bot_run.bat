@echo off
rem Bot batch (docs/BOT.md): tools\bot_run.bat -Runs 500 -Workers 6 -Out build/bot/b1 -Passes journey -Report
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot_run.ps1" %*
