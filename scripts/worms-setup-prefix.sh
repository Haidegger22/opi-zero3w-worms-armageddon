#!/bin/bash
# worms-setup-prefix.sh — создать (или пересоздать) профиль Wine для Worms Armageddon,
# сохранив уже перенесённые файлы игры.
#
# Зачем: если профиль создан недоинициализированным (например `wineboot` убили по
# таймауту), игра падает на старте с «could not load kernel32.dll». Лечится только
# полным пересозданием профиля — этот скрипт делает это, не теряя 542 МБ файлов игры.
#
# Откат: системных изменений нет. Удалить: rm -rf "$WINEPREFIX" "$GAME_SAVE"
set -u

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-worms-hg}"
GAME_SAVE="$HOME/worms-app-save"
LOG="$HOME/worms-prefix.log"
export WINEPREFIX
export DISPLAY="${DISPLAY:-:0}"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu
export WINEDLLOVERRIDES="mscoree,mshtml="

echo "=== 1) откладываю файлы игры в сторону ==="
rm -rf "$GAME_SAVE"
if [ -d "$WINEPREFIX/drive_c/Worms" ]; then
    mv "$WINEPREFIX/drive_c/Worms" "$GAME_SAVE"
    echo "   отложено: $(du -sh "$GAME_SAVE" | cut -f1), файлов $(find "$GAME_SAVE" -type f | wc -l)"
else
    echo "   каталога игры в профиле нет — буду копировать заново"
fi

echo "=== 2) сношу недоинициализированный профиль ==="
timeout 30 wineserver -k 2>/dev/null; sleep 2
rm -rf "$WINEPREFIX"
echo "   профиль удалён"

echo "=== 3) создаю профиль заново (долгий шаг, до 20 минут) ==="
mkdir -p "$WINEPREFIX"
timeout 1500 wineboot -u > "$LOG" 2>&1
echo "   wineboot завершён, код $? (журнал: $LOG)"
timeout 60 wineserver -w 2>/dev/null

echo "=== 4) проверяю, что системные dll на месте ==="
for f in kernel32.dll ntdll.dll ddraw.dll; do
    p=$(find "$WINEPREFIX/drive_c/windows" -iname "$f" 2>/dev/null | head -1)
    printf '   %-14s %s\n' "$f" "${p:-НЕ НАЙДЕН}"
done

echo "=== 5) возвращаю файлы игры на место ==="
mkdir -p "$WINEPREFIX/drive_c"
if [ -d "$GAME_SAVE" ]; then
    mv "$GAME_SAVE" "$WINEPREFIX/drive_c/Worms"
    echo "   возвращено: $(du -sh "$WINEPREFIX/drive_c/Worms" | cut -f1), файлов $(find "$WINEPREFIX/drive_c/Worms" -type f | wc -l)"
fi
echo "=== готово ==="
