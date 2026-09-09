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
- **Update do kernel quebra o DKMS (09/09, omarchy 4.0.3, kernel 7.2.3):** update finalizou com "Something went wrong" — único erro = `dkms install rtl8851bu` exit 10 no kernel novo
  (API cfg80211: `remain_on_channel` ganhou `const u8* rx_addr`; `strncpy` passou a erro sem `#include <string.h>`). FIX (uma mudança, sem reboot até confirmar):
  1. Rebuild do pacote `-git` puxa o HEAD com compat: `yay -S --rebuild rtl8851bu-dkms-git`
     (versão atual p/ 7.2+ = `1.19.10.r46.9e37e7a`, fixes 97a3492 + 2504c16/6a53717). Ou manual:
     `cd ~/.cache/yay/rtl8851bu-dkms-git && git pull && makepkg -f && pkexec pacman -U --noconfirm *.pkg.tar.zst`.
  2. O pacman como root não lê `~` → copiar `.pkg.tar.zst` para `/tmp` antes do `pkexec pacman -U`.
  3. Confirmar ANTES de rebootar: `dkms status` → `rtl8851bu/..., 7.2.3-arch1-3, x86_64: installed`
     (nunca rebootar com `added`).
  4. O post-update "Restore Linux kernel modules" + hook DKMS recompilam sozinhos; rollout se falhar = snapshot Limine.
- Flap 2.4GHz: perfis NM `ZON-5330_Sala*` têm `band a` + `bssid 38:8B:59:E2:38:5A` (5GHz only).
- Verificar `nmcli -g 802-11-wireless.band connection show 'ZON-5330_Sala'` = `a`.

### Rato/teclado com lag no 1º movimento
- USB autosuspend no receptor Logitech. Fix: `echo on > /sys/bus/usb/devices/1-7/power/control`
  + udev rules `91-hid-no-autosuspend.rules` e `90-logitech-no-autosuspend.rules`.

### Jogo Armor Critical (ARC) — Electron crash GPU em Wayland → correr via XWayland
Fonte: revival oficial de Attack Retrieve Capture em https://beta.armorcritical.com/
(Linux AppImage: https://armorcritical-assets.s3.us-east-2.amazonaws.com/releases/linux/armorcritical.AppImage).
Instalado em `~/Games/armorcritical/` (extração, não mount — falta `libfuse.so.2`/fuse2).
SINTOMA: `ac-app` (Electron) aberto direto em Wayland nativo morre com
`GPU process isn't usable. Goodbye` / `GPU process launch failed: error_code=1002`.
FIX: wrapper `~/Games/armorcritical/armorcritical.sh`:
`ELECTRON_OZONE_PLATFORM_HINT=x11` + `LD_LIBRARY_PATH=$HOME/Games/armorcritical/usr/lib`
(Wayland-NOVIDA ao Linux) e `exec ac-app --no-sandbox`. Lançar pelo menu
(`~/.local/share/applications/armorcritical.desktop`, o Exec = wrapper; validar com
`desktop-file-validate`). Testar em background estável: `hyprctl clients` mostra
`class: ac-app, title: ArmorCritical`.
NOTA: `pkill -f 'ac-app'` mata o próprio shell (pattern no cmdline do bash)
→ usar `pkill -x ac-app`.

### Áudio BT AirPods para de funcionar
- Codec deve ser AAC (`a2dp-sink`), não SBC. Se voltar a SBC: reaplicar patch librepods
  (`git apply` em `~/.config/omarchy/plugins/io.github.thisisgm.omapods/daemon/media/profilechoice.hpp`)
  + rebuild cmake + `systemctl --user restart librepods`.
- WirePlumber 0.5.15 tem bug de crash (g_object_unref) — sem trigger não ocorre; atualizar quando houver versão nova.

### AirPods PAR PERDIDO → `AuthenticationRejected` (padrão + fix testado)
Sintomas: `bluetoothctl info` = `Paired:no, Connected:yes`; device liga mas **sem sink A2DP**.
Causa: entrada stale no storage do bluetoothd (`Trusted=false`, sem LinkKey).
FIX (ordem):
1. `bluetoothctl remove 14:28:76:B1:5A:93`
2. agent: `systemd-run --user --unit=btagent bash -c 'exec bluetoothctl --timeout 900 agent NoInputNoOutput'`
3. `bluetoothctl pair 14:28:76:B1:5A:93` → "Pairing successful"
4. `bluetoothctl trust 14:28:76:B1:5A:93`
5. `systemctl --user restart wireplumber`
6. `pactl set-card-profile bluez_card.14_28_76_B1_5A_93 a2dp-sink` (AAC)
7. Verificar `pw-dump` codec=aac + sink default

### AirPods AUTORESUME falha ao tirar/recolocar pod (sem autoplay)
Sintoma: tirar um pod → áudio desliga (beep); recolocar → perfil A2DP reativa mas NÃO faz play.
CAUSA: quando o último pod sai, o perfil vai a `off` e o sink `bluez_output.<MAC>.1` é recriado
**assincronamente** pelo PipeWire. O `setDefaultSink` + `play()` corriam no instante da reativação,
antes do sink existir → falha silenciosa, resume nunca disparava.
FIX (fork `aamsilva/omarchy-pods`, commit `b79edcc`):
1. `handleEarDetection` → `PauseWhenOneRemoved` resumia só com 2 pods
   (`primaryInEar && secondaryInEar`); agora resume com ≥1 (`primaryInEar || secondaryInEar`).
2. Novo `scheduleSinkRestoreAndResume()`: após `activateA2dpProfile()` OK, faz poll 6×500ms
   até o sink voltar a ser default (`m_pulseAudio->setDefaultSink`), restaura volume snap,
   e só então `play()`.
3. Rebuild: `cmake -S daemon -B daemon/build -G Ninja && cmake --build && cmake --install --prefix ~/.local`
   + `systemctl --user restart librepods`.

### AirPods "ligar não funciona" — não é drama, é arranque lento (connect_failures altos)
Sintoma: `librepods-ctl status` → `connected:false`, `connect_failures_total`/`reconnect_failures_total`
a subir; journal mostra "Cannot connect to profile/service / SocketError HostNotFound".
CAUSA: pods em standby + scan LE preso → as tentativas falham. NÃO é par perdido
(verificar: `bluetoothctl info` deve mostrar `Paired:yes Trusted:yes Connected:no`).
FIX: NENHUM — verificar se já ligou passado ~1min (`librepods-ctl status` → connected:true,
`pactl` card bluez com `a2dp-sink`, `pw-dump` codec `[ aac ]`). Só intervir se continuar
`connected:false` após 2-3min: aí sim aplicar o padrão PAR PERDIDO acima.
NOTA: `librepods-ctl ear:one` = behavior 0 (o utilizador usa só 1 pod; right fica `in_ear:false`).

### Áudio metálico/robótico SÓ na TV (HDMI, YouTube webapp soa pior) — causado por formato
Sintoma: áudio distorcido/"metálico" a sair pela TV (TCL via GPU AMD Ellesmere HDMI),
AirPods soam bem (mesmo conteúdo). NOVO sintoma visto: só o YouTube webapp soava mal.
CAUSA: o codec HDMI só suporta `16-bit` (`grep bits /proc/asound/card0/codec#0` → `bits [0x2]: 16`),
mas o sink do PipeWire negociava `s32le` → incompatibilidade → distorção aguda.
FIX: forçar s16le no sink via WirePlumber em `~/.config/wireplumber/wireplumber.conf.d/52-hdmi-s16.conf`
(`monitor.alsa.rules` → match `node.name = alsa_output.pci-0000_1f_00.1.hdmi-stereo-extra3` →
`audio.format = "S16LE"`). Verificar: `pactl list sinks` → `Sample Specification: s16le 2ch 48000Hz`.
Backup: `~/Work/omarchy-config/wireplumber/52-hdmi-s16.conf`. Rollback: apagar ficheiro +
`systemctl --user restart wireplumber`. Confirmado 05/09/2026.

### Patches locais apagados por update de plugins
- Hook `~/.config/omarchy/hooks/post-update.d/reapply-librepods-patch.hook` reaplica automaticamente.
- Verificar se correu: `omarchy hook post-update` (ou procurar no journal).

## Regras de segurança
- **NUNCA** mudar 2 coisas ao mesmo tempo (lição do crash USB).
- **NUNCA** mover o dongle de porta sem verificação (a troca de porta + driver concorrente derreteu o USB).
- Mudanças de hardware/rede: garantir **rollback imediato** + **rede alternativa**.
- `sudo` precisa password interativa → usar `pkexec` para agentes (diálogo no ecrã).
- Root = ler `/usr/share/omarchy/` ok, editar nunca.