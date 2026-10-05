#!/bin/bash
# worms-zero.sh — запуск Worms Armageddon на Orange Pi Zero 3W (Wine/Hangover, arm64).
#
# Что делает:
#   1) гасит прежние процессы этого профиля (иначе второй запуск не поднимется);
#   2) поднимает игру в отдельном профиле Wine — чтобы не мешать другим играм;
#   3) пропускает заставку (она ждёт нажатия клавиши);
#   4) после выхода возвращает режим экрана (игра умеет переключать X на 640x480).
#
# Настройки экрана внутри игры менять ТОЛЬКО через меню ОПЦИИ самой игры:
# реестр она игнорирует, а при переборе режимов X может «залипнуть» (лечится
# перезапуском графического сеанса). Рабочий вариант у нас — 1024x600 оконно.
#
# Откат: удалить этот файл и профиль $WINEPREFIX. Систему скрипт не меняет.

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-worms-hg}"
SCREEN_MODE="${SCREEN_MODE:-1024x600}"     # в какой режим вернуть экран после игры
OUTPUT="${OUTPUT:-}"                        # пусто = определить самому (xrandr)

timeout 25 wineserver -k 2>/dev/null; sleep 2
pkill -x WA.exe 2>/dev/null; sleep 1

export WINEPREFIX
export DISPLAY="${DISPLAY:-:0}"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
# Системные библиотеки вместо вендорских из /usr/local: с вендорскими wine не создаёт GL-контекст
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu

GAME_DIR="$WINEPREFIX/drive_c/Worms"
cd "$GAME_DIR" || { echo "Не найден каталог игры: $GAME_DIR"; exit 1; }

# Определяем выход экрана, если не задан: первый подключённый
if [ -z "$OUTPUT" ] && command -v xrandr >/dev/null; then
    OUTPUT=$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')
fi

echo "Запускаю Worms Armageddon (Wine/Hangover, профиль $WINEPREFIX)..."
wine WA.exe &
WINE_PID=$!

# Заставка требует нажатия: как только окно появилось — активируем и жмём пробел
for i in $(seq 1 40); do
    sleep 3
    W=$(DISPLAY="$DISPLAY" xdotool search --name "Worms Armageddon" 2>/dev/null | tail -1)
    if [ -n "$W" ]; then
        sleep 8
        DISPLAY="$DISPLAY" xdotool windowactivate --sync "$W" 2>/dev/null
        DISPLAY="$DISPLAY" xdotool key --window "$W" --clearmodifiers space 2>/dev/null
        echo "Окно найдено ($W), заставка пропущена."
        break
    fi
done

wait $WINE_PID

# Игра под свой полный экран переключает режим X — возвращаем панель рабочего стола
if [ -n "$OUTPUT" ]; then
    xrandr --output "$OUTPUT" --mode "$SCREEN_MODE" 2>/dev/null \
        && echo "Игра закрыта, режим экрана возвращён в $SCREEN_MODE."
fi

# Напоминание про курсор: если стик в игре ведёт себя рывками, проверьте сторожа
if ! pgrep -f "game-cursor" >/dev/null 2>&1; then
    echo "Подсказка: сторож игрового курсора не запущен — стик в игре может двигать"
    echo "указатель рывками. Как поставить: см. docs/cursor-and-stick.md"
fi
