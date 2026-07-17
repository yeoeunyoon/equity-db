#!/usr/bin/env bash
# Daily data-refresh loop:
#   * on boot: regenerate + reload once (so the app moves off the small
#     committed sample to the full S&P 500), then
#   * every day at REFRESH_AT (UTC): regenerate + reload. Sundays run a full
#     fundamentals sweep (all constituents); other days refresh the TOP-50
#     mega-caps' fundamentals only. Prices always cover the whole universe.
#
# A single failed cycle is logged and skipped, never fatal — the loop keeps the
# app serving the last good load.
set -uo pipefail
cd /app

: "${DB_HOST:=db}"
: "${DB_NAME:=equity_db}"
: "${MYSQL_ROOT_PASSWORD:=root}"
: "${REFRESH_AT:=00:30}"      # HH:MM UTC of the daily run
: "${BOOT_MODE:=daily}"       # mode for the one-time boot refresh (daily|full)
: "${REFRESH_ON_BOOT:=1}"

RELOAD_SQL="docker/reload.sql"

log() { echo "[refresh $(date -u +%FT%TZ)] $*"; }

generate() {  # generate <mode>
  log "generating data (mode=$1) ..."
  python3 generate_data.py --mode "$1"
}

run_reload() {
  log "reloading MySQL from data/*.tsv ..."
  mysql --skip-ssl --host="$DB_HOST" --user=root --password="$MYSQL_ROOT_PASSWORD" \
        "$DB_NAME" < "$RELOAD_SQL"
}

refresh() {  # refresh <mode>; returns non-zero on failure but never exits
  if generate "$1" && run_reload; then
    log "refresh (mode=$1) complete"
  else
    log "refresh (mode=$1) FAILED; keeping previous load, will retry next cycle"
  fi
}

# Seconds from now until the next occurrence of HH:MM UTC.
seconds_until() {
  local now target
  now=$(date -u +%s)
  target=$(date -u -d "today $1" +%s)
  [ "$target" -le "$now" ] && target=$(date -u -d "tomorrow $1" +%s)
  echo $((target - now))
}

log "waiting for MySQL at $DB_HOST ..."
until mysqladmin ping --skip-ssl --host="$DB_HOST" --user=root \
        --password="$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  sleep 3
done
log "MySQL is up"

if [ "$REFRESH_ON_BOOT" = "1" ]; then
  log "boot refresh (mode=$BOOT_MODE)"
  refresh "$BOOT_MODE"
fi

while true; do
  s=$(seconds_until "$REFRESH_AT")
  log "next scheduled refresh in ${s}s (at ${REFRESH_AT} UTC)"
  sleep "$s"
  if [ "$(date -u +%u)" = "7" ]; then   # Sunday -> full sweep
    refresh full
  else
    refresh daily
  fi
done
