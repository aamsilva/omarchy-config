---
name: system-ops
description: >
  Diagnose and fix this machine's recurring infrastructure issues: USB WiFi/BT dongle
  (Realtek RTL8851BU GREEN CM845), Bluetooth AirPods AAC audio, Logitech peripherals,
  USB autosuspend, network stability. Use when WiFi flaps/drops, Bluetooth audio
  stops, mouse/keyboard lag on first movement, USB device crashes, or when the health
  metric (SCORE) drops below 80. Triggers: wifi, bluetooth, airpods, dongle, mouse lag,
  usb crash, autosuspend, flap, beacon loss, health score. See AGENTS.md for full context.
---

# system-ops — infraestrutura desta máquina (aamsilva/Omarchy)

Aplica o framework AutoResearch: UMA mudança por vez, medir antes/depois com metric.py,
rollback imediato, documentar em results.tsv + commit.

## Diagnóstico rápido (nesta ordem)

1. **Métrica de saúde** — `~/Work/omarchy-config/system-experiments/metric.py` (SCORE 0-100)
2. **WiFi** — `iw dev wlp3s0f0u1i2 link` (sinal/banda); `journalctl -u wpa_supplicant | grep BEACON-LOSS`
3. **BT/áudio** — `librepods-ctl status`; `pactl list cards | grep 'Active Profile'` (deve ser `a2dp-sink`=AAC)
4. **USB autosuspend** — `cat /sys/bus/usb/devices/*/power/control` (periféricos devem ser `on`)

## Fixes conhecidos (procedimentos provados)

### Dongle WiFi/BT GREEN (RTL8851BU) crasha ou flapa
- Driver único: `rtw89_8851bu` está blacklisted (`/etc/modprobe.d/90-blacklist-rtw89-8851bu.conf`);
  o OOT `rtl8851bu-dkms-git` deve ser o único a bind. Se aparecerem 2 drivers → crash USB.
- Flap 2.4GHz: perfis NM `ZON-5330_Sala*` têm `band a` + `bssid 38:8B:59:E2:38:5A` (5GHz only).
- Verificar `nmcli -g 802-11-wireless.band connection show 'ZON-5330_Sala'` = `a`.

### Rato/teclado com lag no 1º movimento
- USB autosuspend no receptor Logitech. Fix: `echo on > /sys/bus/usb/devices/1-7/power/control`
  + udev rules `91-hid-no-autosuspend.rules` e `90-logitech-no-autosuspend.rules`.

### Áudio BT AirPods para de funcionar
- Codec deve ser AAC (`a2dp-sink`), não SBC. Se voltar a SBC: reaplicar patch librepods
  (`git apply` em `~/.config/omarchy/plugins/io.github.thisisgm.omapods/daemon/media/profilechoice.hpp`)
  + rebuild cmake + `systemctl --user restart librepods`.
- WirePlumber 0.5.15 tem bug de crash (g_object_unref) — sem trigger não ocorre; atualizar quando houver versão nova.

### Patches locais apagados por update de plugins
- Hook `~/.config/omarchy/hooks/post-update.d/reapply-librepods-patch.hook` reaplica automaticamente.
- Verificar se correu: `omarchy hook post-update` (ou procurar no journal).

## Regras de segurança
- **NUNCA** mudar 2 coisas ao mesmo tempo (lição do crash USB).
- **NUNCA** mover o dongle de porta sem verificação (a troca de porta + driver concorrente derreteu o USB).
- Mudanças de hardware/rede: garantir **rollback imediato** + **rede alternativa**.
- `sudo` precisa password interativa → usar `pkexec` para agentes (diálogo no ecrã).
- Root = ler `/usr/share/omarchy/` ok, editar nunca.