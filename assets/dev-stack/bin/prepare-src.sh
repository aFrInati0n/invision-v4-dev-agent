#!/bin/sh
# Prepare a bind-mounted IC4 source tree so the dev stack (FPM user www-data,
# uid 33) can write to it. Run on the HOST that owns the checkout, as root
# (or with sudo), once per checkout:
#
#   bash dev/bin/prepare-src.sh /path/to/invision-community
#
# What IC4 writes at runtime/install:
#   conf_global.php      install credentials + settings (created from dist)
#   datastore/           compiled templates, compiled data
#   cache/               object/template cache
#   applications/        per-app data dirs (install data, language, themes)
#   plugins/             plugin data
#   uploads/             user uploads + logs
set -eu
SRC="${1:?usage: $0 /path/to/invision-community}"
[ -f "$SRC/init.php" ] || { echo "not an IC4 checkout: $SRC (no init.php)" >&2; exit 1; }

UID_WD="${UID_WD:-33}"

# conf_global.php must exist and be writable by FPM
if [ ! -f "$SRC/conf_global.php" ] && [ -f "$SRC/conf_global.dist.php" ]; then
    cp "$SRC/conf_global.dist.php" "$SRC/conf_global.php"
    echo "created conf_global.php from dist"
fi

mkdir -p "$SRC/datastore" "$SRC/cache" "$SRC/uploads" "$SRC/uploads/logs"
chown -R "$UID_WD:$UID_WD" \
    "$SRC/conf_global.php" \
    "$SRC/datastore" \
    "$SRC/cache" \
    "$SRC/uploads" \
    "$SRC/applications" \
    "$SRC/plugins"
echo "prepare-src: ownership set (uid=$UID_WD) on runtime paths under $SRC"
