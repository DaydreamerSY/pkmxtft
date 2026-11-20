@echo off
rem Re-export game data + sprites from the web project (pokemonAutoChess) into this
rem Godot project: data/pac/*.json, assets/pokemons, assets/portraits.
rem Run it again after adding abilities to data/abilities.json: the Pokemon using
rem them join the pool. Options: --data-only (skip sprites, VFX, audio), --no-music
rem (skip the ~280 MB of music). Also packs assets/vfx (data/ability_vfx.json) and audio.
setlocal
set "PAC_DIR=D:\Python\PKM Autobattle\pokemonAutoChess"
set "NODE_DIR=D:\Python\PKM Autobattle\tools\node"
set "GODOT_DIR=%~dp0.."
set "PATH=%NODE_DIR%;%PATH%"
cd /d "%PAC_DIR%"
call node_modules\.bin\tsx.cmd offline\godot-export.ts "%GODOT_DIR%" %*
