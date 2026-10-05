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
