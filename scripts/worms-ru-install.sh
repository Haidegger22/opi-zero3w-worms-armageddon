#!/bin/bash
# worms-ru-install.sh — тихая установка русской версии Worms Armageddon
# из локального репака (установщик Inno Setup) в отдельный каталог C:\WormsRU.
# Профиль тот же, что у основной сборки, чтобы не плодить Wine-окружения.
#
# Репак — свой, скачанный пользователем: укажите каталог с Setup.exe в REPACK.
# Ключи Inno Setup: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /DIR=...
set -u

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-worms-hg}"
REPACK="${REPACK:-$HOME/Downloads/Worms Armageddon.(v.3.8.1).(1999) [Decepticon] RePack}"
LOG="$HOME/worms-ru-install.log"

export WINEPREFIX
export DISPLAY="${DISPLAY:-:0}"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu
export WINEDLLOVERRIDES="mscoree,mshtml="

cd "$REPACK" || { echo "Нет каталога репака: $REPACK"; exit 1; }
echo "=== запускаю установщик тихо в C:\\WormsRU ==="
timeout 2400 wine Setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /DIR="C:\\WormsRU" > "$LOG" 2>&1
echo "   код установщика: $? (журнал: $LOG)"
timeout 60 wineserver -w 2>/dev/null
echo
echo "=== результат ==="
if [ -d "$WINEPREFIX/drive_c/WormsRU" ]; then
    du -sh "$WINEPREFIX/drive_c/WormsRU" | sed 's/^/   размер: /'
    find "$WINEPREFIX/drive_c/WormsRU" -type f | wc -l | sed 's/^/   файлов: /'
    find "$WINEPREFIX/drive_c/WormsRU" -maxdepth 2 -iname "*.exe" | head -8 | sed 's/^/   /'
else
    echo "   каталог C:\\WormsRU не создан — установщик, видимо, требует диалогов"
    echo "   (тогда ставим через клики; лог: $LOG)"
    tail -10 "$LOG" 2>/dev/null | sed 's/^/      /'
fi
