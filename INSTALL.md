# Установка Worms Armageddon на Orange Pi Zero 3W

Для **Debian 13 (trixie), arm64**, рабочий стол X11 (у нас MATE). Команды — по порядку
в терминале, каждый блок можно копировать целиком. Если `git` не хочется ставить —
в конце файла лежит **полный код всех скриптов**, установка возможна и без репозитория.

Ориентировочное время: Hangover ~10 минут, профиль Wine до 20 минут, копирование игры
2-5 минут, дальше настройки в самой игре.

## Шаг 0. Что понадобится

- **своя копия игры**: чистая GOG-сборка или установщик/репак (Inno Setup);
- ~3,5 ГБ свободного места (Hangover ~2,3 ГБ + профиль с игрой ~2,8 ГБ);
- доступ в интернет на время установки Hangover.

## Шаг 1. Hangover — Wine для arm64

```bash
# зависимости, если ещё не стоят
sudo apt-get update
sudo apt-get install -y curl ca-certificates xdotool x11-utils

# сам Hangover (~280 МБ скачать, ~2,3 ГБ после установки)
bash scripts/01-install-hangover.sh

# проверка
wine --version        # ожидается: wine-11.16 (Hangover)
```

Без интернета на плате: скачайте архив
`hangover_11.16_debian13_trixie_arm64.tar` из релиза
[AndreRH/hangover](https://github.com/AndreRH/hangover/releases/tag/hangover-11.16)
и положите в `~/hangover`, затем запустите скрипт — он не будет качать заново.

## Шаг 2. Профиль Wine

```bash
bash scripts/worms-setup-prefix.sh
```

Скрипт создаёт профиль `~/.wine-worms-hg`. Он же **лечит главную граблю**: если профиль
был создан недоинициализированным (например `wineboot` убили по таймауту), игра падает
с `could not load kernel32.dll`. Скрипт откладывает файлы игры, создаёт профиль заново
и возвращает файлы на место — можно запускать повторно в любой момент.

В конце скрипт печатает три строки — `kernel32.dll`, `ntdll.dll`, `ddraw.dll` должны быть
найдены в профиле. Если хоть один «НЕ НАЙДЕН», повторите шаг.

## Шаг 3. Файлы игры

**Вариант A — у вас уже есть распакованная сборка (так делали мы):**

```bash
WINEPREFIX="$HOME/.wine-worms-hg"
mkdir -p "$WINEPREFIX/drive_c/Worms"
# скопировать ВСЁ содержимое сборки (WA.exe и папки DATA, FESfx, graphics, User, ...)
cp -a /путь/к/распакованной/сборке/. "$WINEPREFIX/drive_c/Worms/"

# проверка
ls "$WINEPREFIX/drive_c/Worms/WA.exe" && \
  echo "файлов: $(find "$WINEPREFIX/drive_c/Worms" -type f | wc -l)"
```

Ожидаемо: файл `WA.exe` на месте, файлов около 4400 (542 МБ).

**Вариант B — установщик GOG.** На Raspberry Pi 4 у нас это работало тихой установкой
(см. репозиторий [pi4-worms-armageddon](https://github.com/Haidegger22/pi4-worms-armageddon)),
на Zero мы просто скопировали уже распакованную сборку:

```bash
export WINEPREFIX="$HOME/.wine-worms-hg"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu
export WINEDLLOVERRIDES="mscoree,mshtml="
cd /путь/к/установщику
wine setup_worms_armageddon_*.exe /SILENT /DIR="C:\\Worms"
timeout 120 wineserver -w
```

## Шаг 4. Лончер и первый запуск

```bash
install -m 755 scripts/worms-zero.sh "$HOME/worms-zero.sh"
bash "$HOME/worms-zero.sh"
```

Что делает лончер: гасит процессы прошлого запуска, поднимает игру в профиле,
ждёт окно и пропускает заставку (она требует нажатия клавиши), а после выхода
возвращает режим экрана `1024x600`.

Проверка, что игра идёт:

```bash
pgrep -c WA.exe                       # 1 — процесс игры
xwininfo -root -children | grep -i worms   # окно Worms Armageddon, 1024x600
```

## Шаг 5. Настройки в самой игре (только через её меню)

- **Экран:** ОПЦИИ → разрешение → **1024×600 оконно**. Игра знает только 4:3 (640×480,
  800×600, 1024×768), 1024×600 принимает только оконно и **только через меню** — правки
  реестра она игнорирует.
- **Перебор режимов делайте по одному.** После нескольких переключений видеорежима X может
  «залипнуть» (чёрный экран или кривая картинка) — лечится перезапуском графического сеанса.
- **Звук:** у нас выставлено около **25 %** — так и оставьте, громче не поднимать.
- **Рендер:** оставить софтверный (`HardwareRendering=0`). Игра не берёт GPU-контекст,
  это её нормальный режим здесь: загрузка CPU ~180 %, температура ~58 °C.

## Шаг 6. Русская версия (по желанию)

```bash
REPACK="$HOME/Downloads/ваш репак с Setup.exe" bash scripts/worms-ru-install.sh
```

Ставится в отдельный каталог `C:\WormsRU` того же профиля. Если установщик требует
диалогов, скрипт скажет об этом и покажет журнал `~/worms-ru-install.log`.

## Шаг 7. Курсор и джойстик (если играете со стика M5Stack)

Игра ведёт курсор сама и перехватывает указатель, поэтому нужны две вещи:

1. **драйвер `m5hub`** с игровым режимом стика — репозиторий
   [opi-zero3w-m5hub](https://github.com/Haidegger22/opi-zero3w-m5hub) (там же пошаговая
   установка службы);
2. **сторож игрового курсора** `game-cursor.py` — он сам включает игровой режим, когда
   на экране окно Worms (класс `wa.exe`), и выключает, когда игра закрыта.

```bash
# сторож (подробности — в репозитории opi-zero3w-cursor-comet)
mkdir -p ~/.local/bin ~/.config/systemd/user
# ... положить game-cursor.py в ~/.local/bin и создать юнит game-cursor.service ...

# проверка во время игры
[ -f /tmp/m5hub-direct ] && echo "игровой режим стика включён"
journalctl --user -u game-cursor -n 5 --no-pager | tail -2
```

Настройка скорости и разбор «догонялок» — в [docs/cursor-and-stick.md](docs/cursor-and-stick.md).

## Шаг 8. Ярлык: рабочий стол и меню

Иконки и сам ярлык лежат в репозитории, в папке `icons/`.

```bash
# иконки: пять размеров + основная (её же читает карусель рабочего стола)
mkdir -p ~/.local/share/icons/worms
cp icons/worms-armageddon-*.png ~/.local/share/icons/worms/
cp icons/worms-armageddon-512.png ~/.local/share/icons/worms-armageddon.png

# ярлык: путь к лончеру подставляем свой
mkdir -p ~/.local/share/applications
sed "s|/home/orangepi|$HOME|g" icons/worms-armageddon.desktop \
    > ~/.local/share/applications/worms-armageddon.desktop
update-desktop-database ~/.local/share/applications

# копия на рабочий стол (MATE требует отметку «доверенный», иначе клик не сработает)
mkdir -p ~/Desktop
cp ~/.local/share/applications/worms-armageddon.desktop ~/Desktop/
chmod +x ~/Desktop/worms-armageddon.desktop
gio set ~/Desktop/worms-armageddon.desktop metadata::trusted true 2>/dev/null

# проверка
desktop-file-validate ~/Desktop/worms-armageddon.desktop && echo "ярлык в порядке"
```

Ярлык появится в меню в разделе **Игры** (категория `Game`) и на рабочем столе.

> ⚠️ Лончер должен быть исполняемым (`chmod +x ~/worms-zero.sh`) — иначе клик по ярлыку
> молча ничего не делает. В самом ярлыке запуск идёт через `bash -c`, поэтому он работает
> даже без права на исполнение у лончера, а журнал запуска остаётся в `/tmp/worms-launch-desktop.log`.

Если иконок нет под рукой (ставите без репозитория) — просто уберите строку `Icon=` из
ярлыка, он будет работать и без картинки.

## Проверка, что всё работает

```bash
wine --version                                  # wine-11.16 (Hangover)
systemctl is-active m5hub                       # active (если играете со стика)
systemctl --user is-active game-cursor          # active
ls "$HOME/.wine-worms-hg/drive_c/Worms/WA.exe"  # файл игры
bash "$HOME/worms-zero.sh"                      # игра запускается, окно 1024x600
```

## Важно

- Скрипты **не меняют систему**, кроме установки самого Hangover (обычные пакеты apt).
- Файлы игры в репозиторий не входят — нужна ваша копия.
- Не правьте настройки экрана в реестре профиля: игра их игнорирует, а X после серии
  переключений залипает.
- Профиль `~/.wine-worms-hg` изолирован: другие игры (Disciples II и т.п.) держите
  в своих профилях.

## Откат

```bash
rm -rf ~/.wine-worms-hg ~/worms-app-save ~/worms-zero.sh
sudo apt-get remove hangover-wine hangover-wowbox64 hangover-libwow64fex hangover-libarm64ecfex
```
## Полный код файлов (установка без git)

Этот раздел — для случая, когда `git` не установлен или репозиторий недоступен:
каждый блок создаёт файл целиком. Порядок запуска — как в шагах 1-6 выше.

### 1. Hangover — Wine для arm64

```bash
mkdir -p $(dirname $HOME/01-install-hangover.sh)
cat > $HOME/01-install-hangover.sh << 'SCRIPT_EOF'
#!/bin/bash
# 1. Hangover — сборка Wine для arm64. Работает там, где box64 графику не даёт.
#    Debian 13 (trixie). Для Debian 12 замени имя архива на debian12_bookworm.
set -e

VER=11.16
TAR="hangover_${VER}_debian13_trixie_arm64.tar"
URL="https://github.com/AndreRH/hangover/releases/download/hangover-${VER}/${TAR}"
D="$HOME/hangover"

echo "==> Качаю Hangover ${VER} (~280 МБ)"
mkdir -p "$D" && cd "$D"
[ -f "$TAR" ] || curl -L --fail -o "$TAR" "$URL"

echo "==> Распаковываю"
tar -xf "$TAR"
ls -la ./*.deb

echo "==> Устанавливаю (потребуется sudo; займёт ~2,3 ГБ)"
sudo apt-get install -y \
  ./hangover-wine_*_arm64.deb \
  ./hangover-wowbox64_*_arm64.deb \
  ./hangover-libwow64fex_*_arm64.deb \
  ./hangover-libarm64ecfex_*_arm64.deb

echo "==> Проверка"
wine --version        # ожидается: wine-11.16 (Hangover)
which wine
du -sh /usr/lib/wine
SCRIPT_EOF
chmod +x $HOME/01-install-hangover.sh 2>/dev/null || true
```

### 2. Профиль Wine для игры

```bash
mkdir -p $(dirname $HOME/worms-setup-prefix.sh)
cat > $HOME/worms-setup-prefix.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/worms-setup-prefix.sh 2>/dev/null || true
```

### 3. Запуск Worms Armageddon

```bash
mkdir -p $(dirname $HOME/worms-zero.sh)
cat > $HOME/worms-zero.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/worms-zero.sh 2>/dev/null || true
```

### 4. Русская версия из репака

```bash
mkdir -p $(dirname $HOME/worms-ru-install.sh)
cat > $HOME/worms-ru-install.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/worms-ru-install.sh 2>/dev/null || true
```


### 5. Ярлык (рабочий стол и меню)

Иконки в этот блок не вставить — это картинки. Возьмите их из папки `icons/` репозитория
(файлы `worms-armageddon-48/64/128/256/512.png`), либо уберите строку `Icon=` — ярлык
будет работать и без картинки.

```bash
mkdir -p $HOME/.local/share/icons/worms
# сюда положите пять PNG из папки icons/ репозитория, затем:
cp $HOME/.local/share/icons/worms/worms-armageddon-512.png $HOME/.local/share/icons/worms-armageddon.png

cat > $HOME/worms-armageddon.desktop << 'SCRIPT_EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Worms Armageddon
Name[ru]=Worms Armageddon
Comment=Запуск Worms Armageddon (Hangover/Wine, профиль ~/.wine-worms-hg)
Exec=bash -c "/home/orangepi/worms-zero.sh >> /tmp/worms-launch-desktop.log 2>&1"
Icon=/home/orangepi/.local/share/icons/worms-armageddon.png
Terminal=false
Categories=Game;ActionGame;
Keywords=worms;черви;armageddon;
StartupNotify=true
SCRIPT_EOF
sed -i "s|/home/orangepi|$HOME|g" $HOME/worms-armageddon.desktop

mkdir -p $HOME/.local/share/applications $HOME/Desktop
cp $HOME/worms-armageddon.desktop $HOME/.local/share/applications/
cp $HOME/worms-armageddon.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/worms-armageddon.desktop
gio set $HOME/Desktop/worms-armageddon.desktop metadata::trusted true 2>/dev/null || true
update-desktop-database $HOME/.local/share/applications 2>/dev/null || true
```

