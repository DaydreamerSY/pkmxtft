@echo off
rem Screenshots of the game without disturbing whoever uses the PC: Godot runs on a hidden Windows
rem desktop (no window shown, no focus, no mouse) with the sound off. See tools\screenshot_hidden.ps1.
rem   tools\screenshot_hidden.bat <output dir> [menu ^| synergy ^| vfx ...] [lang=vi] [pass=5]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0screenshot_hidden.ps1" %*
