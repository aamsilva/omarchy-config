# INCIDENTE 2026-08-26 ~02:30 — REVERTIDO

O dongle GREEN CM845 (RTL8851BU, WiFi+BT) crashou o barramento USB ao ser
religado numa porta diferente (u2 em vez de u1), ~90s antes de reset forçado.

## Causa
Dois drivers competiam pelo mesmo chip:
- `rtl8851bu-dkms-git` (out-of-tree) — funcionou estável toda a noite na porta u1
- `rtw89_8851bu` (in-tree kernel) — assumiu na nova porta e derreteu o USB

## Correções aplicadas (estado atual)
- ✅ `/etc/modprobe.d/90-blacklist-rtw89-8851bu.conf` — força sempre o driver OOT
- ↩️ REVERTIDO: regra udev autosuspend (era `90-usb-wifi-no-autosuspend.rules`)
- ↩️ REVERTIDO: band pin 5GHz e ignore-auto-dns na ligação 'ZON-5330_Sala'
- ✅ MANTIDO: systemd-resolved + DoT (`dot.conf`) — agora só como fallback
  (DNS primário voltou a ser o router via DHCP)
- ✅ MANTIDO: configs WirePlumber AAC + patch librepods (áudio, sem relação)

## Regras para religar o GREEN (quando testado)
1. Ligar na MESMA porta física de antes (a que dava wlp32s0f3u1i2 / usb 3-1)
2. Ter alguém a ver `journalctl -kf` durante a ligação
3. Se USB começar a cuspir erros -110 noutros dispositivos → desligar já
