@echo off
cd /d "%~dp0"
del galaxian.nes galaxian.map galaxian_labels.txt 2>nul
ca65 -g src/main.asm -o src/main.o
if errorlevel 1 exit /b 1
ld65 -C config.cfg -Ln galaxian_labels.txt -m galaxian.map -o galaxian.nes src/main.o
