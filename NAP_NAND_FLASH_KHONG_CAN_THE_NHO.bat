@echo off
title Nap BOOT.BIN vao NAND Flash tren mach EBAZ4205 (Khong can the nho SD)
echo ============================================================================
echo   NAP GAME VAO CHIP NHO NAND FLASH (nand-x8) TREN BO MACH EBAZ4205
echo ============================================================================
echo.
echo Dam bao mach da cap nguon va cam cap JTAG.
echo Neu Vivado Hardware Manager dang mo, hay dong Target hoac tat Vivado truoc.
echo.
"D:\vivado\Vitis\2024.2\bin\program_flash.bat" -f "E:\Game_Datapath_V2\BOOT.BIN" -offset 0 -flash_type nand-x8 -fsbl "E:\Game_Datapath_V2\vitis_game_v2\platformgame_platform_v2\export\platformgame_platform_v2\sw\boot\fsbl.elf" -verify
echo.
echo ============================================================================
echo Hoan tat! Hay rut cap JTAG (hoac chuyen jumper Boot sang NAND) va cap nguon lai.
echo ============================================================================
pause
