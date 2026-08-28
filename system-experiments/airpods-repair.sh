#!/bin/bash
# AirPods Pro 2 auto-repair — recupera par perdido/sem sink de áudio.
# Uso: airpods-repair.sh   (sem argumentos, MAC dos AirPods fixo)
# Baseado no padrão documentado (PAR PERDIDO -> AuthenticationRejected).
set -u

NONINTERACTIVE=0
[ "${1:-}" = "--noninteractive" ] && NONINTERACTIVE=1

MAC="14:28:76:B1:5A:93"
CARD="bluez_card.${MAC//:/_}"
SINK="bluez_output.${MAC//:/_}.1"

say()  { echo -e "\033[1m$*\033[0m"; }
ok()   { echo -e "  \033[32m✓\033[0m $*"; }
fail() { echo -e "  \033[31m✗\033[0m $*"; }

# 0. Agente persistente (root cause do AuthenticationRejected)
say "Passo 0: garantir agente BT persistente"
systemctl --user enable --now bt-agent.service >/dev/null 2>&1
if systemctl --user is-active --quiet bt-agent.service; then
  ok "bt-agent.service ativo"
else
  fail "bt-agent.service inativo — a iniciar transient"
  systemd-run --user --unit=btagent bash -c 'exec bluetoothctl --timeout 900 agent NoInputNoOutput' >/dev/null 2>&1
fi

# 1. Ver estado atual
say "Passo 1: estado atual"
info=$(timeout 5 bluetoothctl info "$MAC" 2>/dev/null)
paired=$(echo "$info" | grep -c "^[[:space:]]*Paired: yes")
connected=$(echo "$info" | grep -c "^[[:space:]]*Connected: yes")

if [ "$paired" -eq 1 ] && [ "$connected" -eq 1 ]; then
  ok "Já paired+connected"
  # só garantir sink A2DP
  say "Passo 2: garantir sink AAC"
  pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null
  pactl set-default-sink "$SINK" 2>/dev/null
  codec=$(pw-dump 2>/dev/null | python3 -c "import json,sys
for o in json.load(sys.stdin):
    if o['type']=='PipeWire:Interface:Node' and '$SINK' in json.dumps(o['info'].get('props',{})):
        print(o['info']['props'].get('api.bluez5.codec')); break")
  ok "codec=${codec:-?}"
  exit 0
fi

# 2. Se paired mas sem sink de áudio (Par perdido lógico)
if [ "$paired" -eq 1 ] && [ "$connected" -eq 0 ]; then
  say "Passo 2: paired mas desconectado — a conectar"
  timeout 20 bluetoothctl connect "$MAC" 2>/dev/null | grep -q "Connection successful" && ok "conectado" \
    || fail "connect falhou (AirPods podem estar no estojo)"
fi

# 3. Se não está paired (par perdido físico) — precisa pairing mode
if [ "$paired" -eq 0 ]; then
  if [ "$NONINTERACTIVE" -eq 1 ]; then
    say "Não-interativo: AirPods sem par — deixar (requer pairing mode manual)"
    notify-send -u normal -t 8000 "AirPods: par perdido" "Corre airpods-repair.sh no terminal para re-parear" 2>/dev/null || true
    exit 1
  fi
  echo
  say "⚠ Os AirPods NÃO estão pareados (par perdido no firmware Apple)."
  say "  Põe os AirPods em MODO DE EMPARELHAMENTO:"
  say "  → copo aberto, prime e segura o botão traseiro até o LED piscar BRANCO."
  read -r -p "  Carrega ENTER quando estiverem a piscar... " _
  echo

  say "Passo 3: scan + pair"
  timeout 8 bluetoothctl scan on >/dev/null 2>&1
  sleep 1
  timeout 5 bluetoothctl devices 2>/dev/null | grep -q "$MAC" && ok "device visível" || {
    timeout 10 bluetoothctl scan on >/dev/null 2>&1
    sleep 1
  }
  timeout 5 bluetoothctl devices 2>/dev/null | grep -q "$MAC" || fail "device não aparece no scan"
  if ! timeout 25 bluetoothctl pair "$MAC" 2>&1 | grep -q "Pairing successful"; then
    fail "pair falhou"
    # Um retry após pausa ajuda no InProgress (rádio saturar)
    sleep 3
    timeout 25 bluetoothctl pair "$MAC" 2>&1 | grep -q "Pairing successful" && ok "pair OK (retry)" || { fail "pair falhou de novo"; exit 1; }
  else
    ok "pair OK"
  fi
fi

# 4. Trust + connect
say "Passo 4: trust + connect"
timeout 5 bluetoothctl trust "$MAC" >/dev/null 2>&1 && ok "trusted"
timeout 25 bluetoothctl connect "$MAC" 2>/dev/null | grep -q "Connection successful" && ok "conectado" || fail "connect falhou"

# 5. Perfil AAC
say "Passo 5: sink AAC"
sleep 3
pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null
sleep 1
pactl set-default-sink "$SINK" 2>/dev/null
codec=$(pw-dump 2>/dev/null | python3 -c "import json,sys
for o in json.load(sys.stdin):
    if o['type']=='PipeWire:Interface:Node' and '$SINK' in json.dumps(o['info'].get('props',{})):
        print(o['info']['props'].get('api.bluez5.codec')); break")
[ -n "${codec:-}" ] && ok "codec=$codec" || fail "sem sink A2DP — restart wireplumber"
if [ -z "${codec:-}" ]; then
  systemctl --user restart wireplumber
  sleep 3
  pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null
  pactl set-default-sink "$SINK" 2>/dev/null
  codec=$(pw-dump 2>/dev/null | python3 -c "import json,sys
for o in json.load(sys.stdin):
    if o['type']=='PipeWire:Interface:Node' and '$SINK' in json.dumps(o['info'].get('props',{})):
        print(o['info']['props'].get('api.bluez5.codec')); break")
  [ -n "${codec:-}" ] && ok "codec=$codec (após restart WP)" || fail "ainda sem sink"
fi

say "Concluído."