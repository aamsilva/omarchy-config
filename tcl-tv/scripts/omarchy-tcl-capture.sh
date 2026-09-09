#!/usr/bin/env bash
# Omarchy → TCL TV bridge: captura os keyevents do RCU por polling do logcat
# da TV (via ADB) e espelha-os para o script de mapeamento Omarchy.
#
# Como funciona:
#   - O RCU TCL é Bluetooth HID; o keycode chega como KeyEvent sintético à
#     activity TVActivity (do TCL), que o loga em debug com formato parseável.
#   - Fazemos polling incremental do buffer logcat da TV; extraímos os
#     KEYCODE_*; deduplicamos pelo timestamp do evento; invocamos o mapper.
#
# Uso:
#   omarchy-tcl-capture.sh [tv_ip] [mapper_cmd...]
#     tv_ip        default 192.168.86.55
#     mapper_cmd   default: omarchy-tcl-relay.sh keyevent
#
# Deps: adb (platform-tools), omarchy-tcl-relay.sh (mapper local).

set -uo pipefail

TV_IP="${1:-192.168.86.55}"
MAPPER=("${@:2}")
if [[ ${#MAPPER[@]} -eq 0 ]]; then
    MAPPER=(bash "$(dirname "$0")/omarchy-tcl-relay.sh" keyevent)
fi

ADB=(adb -s "${TV_IP}:5555")
LAST_MARKER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/tcl-tv-logcat-marker"

# --- gestão do marker de progresso (evita reprocessar todo o log cada vez) ---
get_marker() {
    [[ -f "$LAST_MARKER_FILE" ]] && cat "$LAST_MARKER_FILE" || echo ""
}
set_marker() { echo "$1" > "$LAST_MARKER_FILE"; }

# --- extrai KEYCODE_* únicos da linha, escapados de duplicados por eventTime ---
# logcat -v threadtime: "  09-04 18:06:58.101   726  1870 D WindowManager: ... keyCode=KEYCODE_DPAD_UP, scanCode=0, ... eventTime=5287491544, ..."
extract_keys() {
    # por evento (eventTime) registamos o conjunto de keycodes vistos
    # e só emitimos o primeiro (o log do WindowManager/D-fase é suficiente)
    awk '
        /keyCode=KEYCODE_[A-Z_0-9]+/ {
            code = ""
            ts = ""
            time = ""
            # pegar keyCode
            if (match($0, /keyCode=KEYCODE_[A-Z_0-9]+/)) {
                code = substr($0, RSTART+8, RLENGTH-8)
            }
            # pegar eventTime (para deduplicar repetições do mesmo evento)
            if (match($0, /eventTime=[0-9]+/)) {
                ts = substr($0, RSTART+10, RLENGTH-10)
            }
            # pegar a marcacao de tempo log (evitar reenvio de linhas antigas do buffer)
            if (match($0, /[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+/)) {
                time = substr($0, RSTART, RLENGTH)
            } else if (match($0, /^[0-9]+$/)) { time = $0 }
            if (code != "" && ts != "") {
                key = code "\t" ts "\t" time
                if (!seen[key]++) print code
            }
        }'
}

# --- ciclo principal de polling ---
echo "TCL-capture: conectando a ${TV_IP}:5555 ..."
"${ADB[@]}" connect "${TV_IP}:5555" >/dev/null 2>&1 || { echo "ERRO: não consigo connectar" >&2; exit 1; }

# verifica acesso
if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
    echo "ERRO: adb sem acesso à TV ${TV_IP}" >&2
    exit 1
fi

LAST_MARKER="$(get_marker)"
echo "TCL-capture: a monitorizar (marker=@${LAST_MARKER:-boot})..."

while true; do
    # dump do logcat com linhas desde o marker; se marker vazio, só as últimas 2000
    if [[ -n "$LAST_MARKER" ]]; then
        OUTPUT=$("${ADB[@]}" shell "logcat -v threadtime -t \"${LAST_MARKER}\" 2>/dev/null" 2>/dev/null)
    else
        OUTPUT=$("${ADB[@]}" shell "logcat -v threadtime -d 2>/dev/null" 2>/dev/null)
    fi

    # atualizar marker para a última linha (formato logcat threadtime)
    lastline=$(printf '%s\n' "$OUTPUT" | grep -oE '^[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | tail -1)
    if [[ -n "$lastline" ]]; then
        # o logcat -t aceita "" depois do boot; usamos o último timestamp completo
        LAST_MARKER="$lastline"
        set_marker "$lastline"
    fi

    # extrair keycodes novos e despachar
    printf '%s\n' "$OUTPUT" | extract_keys | while IFS= read -r keycode; do
        echo "TCL-capture: RCU → $keycode"
        "${MAPPER[@]}" "$keycode"
    done

    # poll de 0.5s para latência baixa sem stressar adb
    sleep 0.5
done