@echo off
cd /d "C:\Projects\DotaGrider"
powershell -ExecutionPolicy Bypass -NoProfile -File "GenerateHeroGrid.ps1"
%*
