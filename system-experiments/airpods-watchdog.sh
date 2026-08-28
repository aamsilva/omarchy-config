#!/bin/bash
# AirPods proximity watchdog — auto-reconnect quando os AirPods voltam ao alcance
# mas o BlueZ não responde ao page (scan LE preso no rádio combo Realtek).
# Corre de 1 em 1 minuto via omarchy-airpods-watchdog.timer.
set -u

MAC="14:28:76:B1:5A:93"
LOCK="/tmp/airpods-watchdog.lock"

# Evitar corrida se o serviço demorar mais que o intervalo do timer.
[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

info=$(timeout 5 bluetoothctl info "$MAC" 2>/dev/null)
connected=$(echo "$info" | grep -c "^[[:space:]]*Connected: yes")

# Já ligado — nada a fazer.
[ "$connected" -eq 1 ] && exit 0

# Sem par → o watchdog não consegue (precisa de pairing mode manual).
echo "$info" | grep -q "^[[:space:]]*Paired: yes" || exit 0

# Device em cache? Se não, um scan curto dá-lhe vida (cache é apagado com o tempo).
timeout 5 bluetoothctl devices 2>/dev/null | grep -q "$MAC" || {
  timeout 8 bluetoothctl scan on >/dev/null 2>&1
  sleep 2
}

# Em alcance? RSSI presente no cache = o LE adv está a chegar.
rssi=$(timeout 5 bluetoothctl info "$MAC" 2>/dev/null | grep -oE 'RSSI: 0x[0-9a-f]+' | head -1)
[ -n "$rssi" ] || exit 0

# Em alcance e paired mas desligado → reconnect.
timeout 20 bluetoothctl connect "$MAC" >/dev/null 2>&1
logger -t airpods-watchdog "reconnect tentado ($rssi)"
exit 0