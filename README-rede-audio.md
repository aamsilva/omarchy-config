# Otimizações de rede/áudio (2026-08-26)

## Restauração rápida

### 1. WiFi/BT dongle (RTL8851BU — GREEN CM845 AX900, partilhado WiFi+BT)
```bash
# autosuspend off (imediato + persistente)
sudo cp udev/90-usb-wifi-no-autosuspend.rules /etc/udev/rules.d/
sudo udevadm control --reload
echo on | sudo tee /sys/bus/usb/devices/3-1/power/control
```

### 2. WirePlumber (AirPods AAC, sem SBC-XQ)
```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp wireplumber/*.conf ~/.config/wireplumber/wireplumber.conf.d/
systemctl --user restart pipewire wireplumber
```
Nota: `bluetooth.lua.d/*.bak-0.4` é formato antigo (0.4) mantido só por referência — NÃO carrega no WP 0.5+.

### 3. DNS com DoT (systemd-resolved)
```bash
sudo mkdir -p /etc/systemd/resolved.conf.d /etc/NetworkManager/conf.d
sudo cp systemd/dot.conf /etc/systemd/resolved.conf.d/
sudo cp NetworkManager/dns-resolved.conf /etc/NetworkManager/conf.d/
sudo systemctl enable --now systemd-resolved
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
nmcli connection modify 'ZON-5330_Sala' ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
nmcli device disconnect wlp32s0f3u1i2 && sleep 3 && nmcli device connect wlp32s0f3u1i2
```
Resultado: fresh ~10ms (era 38ms), cache hits 0ms.
CUIDADO: o drop-in tem de estar em `/etc/systemd/resolved.conf.d` (com "d" em resolved), não `resolved.conf.d`.

### 4. Patch librepods → AAC (omapods)
O ranking de perfis por bitrate bruto escolhia SBC(328k) sobre AAC(256k).
Patch: prioridade PipeWire primeiro (AAC prio 131 > SBC 130).
```bash
cd ~/.config/omarchy/plugins/io.github.thisisgm.omapods
git apply omapods/aac-priority.patch   # a partir deste repo
cmake -S daemon -B daemon/build -G Ninja -DBUILD_TESTING=OFF
cmake --build daemon/build && cmake --install daemon/build --prefix ~/.local
systemctl --user restart librepods.service
```
Verificar: `pactl list cards | grep 'Active Profile'` deve mostrar `a2dp-sink` (= AAC nesta stack).

## Contexto
- Root cause da instabilidade: flap 2.4GHz por coexistência BT/WiFi no mesmo dongle
  (beacon loss em série quando AirPods ativos) + autosuspend USB.
- Fix decisivo: banda fixada em 5GHz (`nmcli ... 802-11-wireless.band a`) — não está em ficheiros,
  é propriedade da ligação NM 'ZON-5330_Sala'.
- WirePlumber 0.5.15 tem bug conhecido (crash g_object_unref após falha A2DP); sem triggers
  não ocorre. Atualizar quando sair versão nova.
SSH auth configurado 2026-08-26 22:29:10
