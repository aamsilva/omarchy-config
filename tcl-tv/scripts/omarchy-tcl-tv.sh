#!/usr/bin/env bash
# Omarchy → TCL TV: controlo direto (direção fiável via ADB).
#
# Uso:
#   omarchy-tcl-tv.sh hdmi1      → muda a TV para o input HDMI1 (Omarchy)
#   omarchy-tcl-tv.sh key <code> → envia keyevent Android (ex: 4=back, 3=home)
#   omarchy-tcl-tv.sh status     → mostra se a ligação ADB à TV está ativa

set -euo pipefail

TV_IP="${TCL_TV_IP:-192.168.86.55}"
ADB=(adb -s "${TV_IP}:5555")

cmd="${1:-status}"

case "$cmd" in
  hdmi1)
    # TCL Google TV: intent direto de switch para HDMI1 (HW15)
    "${ADB[@]}" connect "${TV_IP}:5555" >/dev/null 2>&1 || true
    "${ADB[@]}" shell am start \
        -a android.intent.action.VIEW \
        -d "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW15" 2>&1 | grep -vE "^$" || echo "ordem enviada"
    ;;
  key)
    code="${2:?uso: $0 key <android_keycode>}"
    "${ADB[@]}" connect "${TV_IP}:5555" >/dev/null 2>&1 || true
    "${ADB[@]}" shell input keyevent "$code" 2>&1 | grep -vE "^$" || echo "keyevent ${code} enviado"
    ;;
  status)
    "${ADB[@]}" connect "${TV_IP}:5555" >/dev/null 2>&1 || true
    state=$("${ADB[@]}" get-state 2>/dev/null || echo offline)
    echo "TV ${TV_IP}: ${state}"
    ;;
  *)
    echo "uso: $0 {hdmi1|key <code>|status}" >&2
    exit 1
    ;;
esac