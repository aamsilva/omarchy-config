#!/usr/bin/env bash
# Omarchy TV-like experience: mapeia keyevents ejectados pela TV TCL
# (via relay ADB) em ações Omarchy/Wayland.
#
# INPUT: linhas na forma "KEYCODE_MEDIA_PLAY_PAUSE" (uma por linha, via stdin
#        ou argumento), como espelhadas pelo serviço na TV.
# OUTPUT: executa a ação correspondente (wtype / hyprctl / notificação).
#
# Uso:
#   omarchy-tcl-relay.sh keyevent "KEYCODE_DPAD_UP"
#   nc -l 192.168.86.32 7001 | omarchy-tcl-relay.sh listen

set -euo pipefail

# ---------------------------------------------------------------- util
_notify() {
    notify-send -a "TCL Remote" "$1" "$2" 2>/dev/null || true
}

# ---------------------------------------------------------------- acoes Wayland
# Navegação d-pad, OK, back, home -> teclas de seta / Return / Esc / Super
_act_dpad_up()        { wtype -k Up; }
_act_dpad_down()      { wtype -k Down; }
_act_dpad_left()      { wtype -k Left; }
_act_dpad_right()     { wtype -k Right; }
_act_dpad_center()    { wtype -k Return; }
_act_back()           { wtype -k Escape; }
_act_home()           { hyprctl dispatch exec launch-on-workspace 1 com.faos.quickshell.launcher 2>/dev/null || wtype -M Super -k Space -m Super; }
_act_menu()           { wtype -M Super -k m -m Super; }   # menu omnarchy
_act_settings()       { hyprctl dispatch exec "xterm -e systemctl --user status" >/dev/null 2>&1; }
_act_enter()          { wtype -k Return; }

# Media
_act_media_play_pause() { wtype -M Ctrl -k space -m Ctrl; }
_act_media_next()       { wtype -M Ctrl -k Right -m Ctrl; }
_act_media_previous()   { wtype -M Ctrl -k Left -m Ctrl; }

# Volume (trata via pipewire)
_act_volume_up()   { wpctl set-volume @DEFAULT_SINK@ 5%+; }
_act_volume_down() { wpctl set-volume @DEFAULT_SINK@ 5%-; }
_act_mute()        { wpctl set-mute @DEFAULT_SINK@ toggle; }

# Power -> bloquear ecrã (sem perder o power realmente, o RCU manda na TV)
_act_power()       { hyprctl dispatch exec loginctl lock-session; }

# Números (numpad menu) -> atalhos de workspace? mantemos simples: enviar Lookup
_act_numpad() {
    local n="$1"
    wtype -k "KP_${n}"
}

# Channel up/down -> page up/down (scroll)
_act_channel_up()   { wtype -k Page_Up; }
_act_channel_down() { wtype -k Page_Down; }

_act_task_switcher() { hyprctl dispatch overview >/dev/null 2>&1 || wtype -M Super -k Tab -m Super; }
_act_assistant()     { _notify "TCL Remote" "Google Assistant não disponível no Omarchy"; }

# ---------------------------------------------------------------- mapa principal
declare -A ACTIONS=(
  [KEYCODE_DPAD_UP]=dpad_up
  [KEYCODE_DPAD_DOWN]=dpad_down
  [KEYCODE_DPAD_LEFT]=dpad_left
  [KEYCODE_DPAD_RIGHT]=dpad_right
  [KEYCODE_DPAD_CENTER]=dpad_center
  [KEYCODE_BACK]=back
  [KEYCODE_HOME]=home
  [KEYCODE_MENU]=menu
  [KEYCODE_ENTER]=enter
  [KEYCODE_VOLUME_UP]=volume_up
  [KEYCODE_VOLUME_DOWN]=volume_down
  [KEYCODE_MUTE]=mute
  [KEYCODE_POWER]=power
  [KEYCODE_MEDIA_PLAY_PAUSE]=media_play_pause
  [KEYCODE_MEDIA_NEXT]=media_next
  [KEYCODE_MEDIA_PREVIOUS]=media_previous
  [KEYCODE_CHANNEL_UP]=channel_up
  [KEYCODE_CHANNEL_DOWN]=channel_down
  [KEYCODE_TV_POWER]=power
  [KEYCODE_TASK_SWITCHER]=task_switcher
  [KEYCODE_ASSIST]=assistant
)

_run_action() {
    local key="$1"
    local act="${ACTIONS[$key]:-}"
    if [[ -z "$act" ]]; then
        # número
        if [[ "$key" =~ ^KEYCODE_NUMPAD_([0-9])$ ]]; then
            _act_numpad "${BASH_REMATCH[1]}"
            return 0
        fi
        echo "TCL-remote: key sem mapeamento: $key" >&2
        return 0
    fi
    echo "TCL-remote: $key -> $act" >&2
    "_act_${act}"
}

# ---------------------------------------------------------------- modos
case "${1:-}" in
  listen)
      # ncat/nc disponivel? usar ncat se existir
      if command -v ncat >/dev/null; then
          exec ncat -l -k 192.168.86.32 7001 --sh-exec "$0 serve"
      elif command -v nc >/dev/null; then
          exec nc -l -k 192.168.86.32 7001 | while IFS= read -r line; do
              [[ -z "$line" ]] && continue
              "$0" keyevent "$line"
          done
      else
          echo "TCL-remote: nem ncat nem nc disponíveis" >&2
          exit 1
      fi
      ;;
  keyevent)
      _run_action "$2"
      ;;
  *)
      echo "Uso: $0 {listen|keyevent KEYCODE_...}" >&2
      exit 1
      ;;
esac