# Memória do sistema (aamsilva / Omarchy)

## Gestor de plugins Omarchy

Instalar/gerir shell-plugins e widgets da barra:

```bash
omarchy plugin add https://github.com/<user>/<repo>.git --enable --yes
omarchy plugin list                     # instalados + estado + fonte
omarchy plugin enable/disable/remove <id>
omarchy plugin update                   # atualiza todos os git-plugins
omarchy bar move <id> --section center --after omarchy.weather   # posicionar widget
omarchy-shell shell rescanPlugins       # forçar reload do código QML/JS/python
```

- Marketplace: https://omarchyplugins.com — catálogo real em JSON:
  `https://raw.githubusercontent.com/HANCORE-linux/omarchy-plugin-marketplace/main/site/catalog.json`
  (a página web é client-side renderizada; usar o catalog.json para pesquisar)
- Plugins first-party: `/usr/share/omarchy/shell/plugins/` (NÃO editar)
- Plugins do utilizador: `~/.config/omarchy/plugins/<id>/` (editáveis; hot-reload ao gravar)
- Barra: `~/.config/omarchy/shell.json` (hot-reload). Layout atual:
  left = menu, workspaces, **argus** · center = indicators, clock, keyboard-layout, weather,
  **nvme-health**, microphone, system-update

## Plugin Argus (io.github.diegopluna.argus) — monitor tipo exelban/Stats

Fonte: https://github.com/diegopluna/omarchy-argus. Réplica do Stats (macOS): widget de barra
com segmentos configuráveis + painel com tabs CPU/GPU/MEM/DISK/NET/PROC/TEMP/BAT/BAR,
sparklines 2min/1h, alertas por threshold, PSI pressure, SMART por disco.
Sampler: `bash sample.sh static|dynamic|health|ps` (testável à mão no dir do plugin).
Config `show` TEM de ser array JSON real em shell.json — `omarchy bar set <id> show '[...]'
grava string e o plugin ignora (Model.normalizeShow exige instanceof Array); editar shell.json
diretamente. Barra atual: cpu, cputemp, gputemp, ram, disk, net.
Sensores locais detetados: k10temp (Tctl), amdgpu (edge temp, fan1 RPM, PPT power), TR200 health.

## Plugin NVMe Health (io.github.qadram.nvme-health) — CUSTOMIZADO

Fonte original: https://github.com/qadram/omarchy-nvme-health (repo correto; `qadram/nvme-health` a solo não existe).
Mostra SMART de SSDs/HDDs **NVMe e SATA** via UDisks2 (sem root). Disco local: TOSHIBA TR200 480GB SATA (/dev/sda).

Patches locais aplicados em `~/.config/omarchy/plugins/io.github.qadram.nvme-health/`
(um `omarchy plugin update` os pode sobrescrever — reaplicar se necessário):

1. `status.py` — `ata_attr_raw` agora lê linhas em **tuple** `(id, name, flags, value, worst, thresh, raw, type)` além de dicts, e aceita nomes com hífen (`power-on-hours`, `reallocated-sector-count`) além de underscore.
2. `summarize_ata` — horas preferem `SmartPowerOnSeconds` (o TR200 reporta power-on-hours raw em milissegundos!); adicionados: temperatureC (Kelvin→°C), powerCycleCount, numBadSectors, numAttrsFailing, selftestStatus, sizeBytes, serial, firmware. Warning também com bad sectors/attrs failing > 0.
3. `Model.js` — formatadores novos: formatTemp, formatCount, formatBytes, formatSelftest, identityLine; barLabel mostra `OK · 32°C`.
4. `Panel.qml` — painel com todas as métricas novas + linha identidade (disco · tamanho · fw · S/N).

Dados que o firmware TR200 NÃO expõe (ficam "—" honestamente): % vida restante, setores realocados, TBW fiável (attr F1 usa unidades não-standard neste modelo).

## Atalhos e agente

- Agente default: opencode (`~/.config/omarchy/defaults/agent`)
- `SUPER + SHIFT + A` → Agent (opencode) — trocado via `hl.unbind` + `o.bind` em `~/.config/hypr/bindings.lua`; ChatGPT foi desligado desse atalho
- `SUPER + CTRL + V` → painel Vitals (plugin io.github.woogy7.vitals)

## Diversos

- GitHub: conta **aamsilva** (aamsilva@gmail.com), `gh` autenticado via keyring. Repos próprios:
  - `aamsilva/omarchy-nvme-health` — fork patchado do nvme-health; fonte local `~/Work/omarchy-nvme-health`
  - `aamsilva/omarchy-config` — backup shell.json/bindings.lua/plugins; fonte local `~/Work/omarchy-config`
  - `aamsilva/omarchy-argus` — fork do Argus: clicar num segmento da barra abre a tab respetiva
    (temp→TEMP, net→NET, …); fonte local `~/Work/omarchy-argus`; patch em BarWidget.qml
    (tabForMetric/openSegmentTab; label escondida mantém sizing; MouseAreas só LeftButton).
    Nota: sem .github/ (token sem scope workflow); `gh auth setup-git` já configurado.
- Mudanças nos plugins QML/JS hot-reload ao gravar; mudanças no backend python/QML estrutural
  → `omarchy restart shell` para garantir.
- sudo requer password interativa (não há NOPASSWD nem secrets.env) — para comandos root, pedir ao utilizador para correr no terminal
- Hardware: GPU AMD RX 570/580, WiFi USB GREEN CM845 AX900 (rtl8851bu), SSD Toshiba TR200 SATA

## Rede/áudio — fixes que ficaram (tudo documentado em ~/Work/omarchy-config)

- **WiFi GREEN CM845 (RTL8851BU, WiFi+BT num chip, usb 3-1 porta traseira):** havia DOIS drivers a competir (`rtl8851bu-dkms-git` OOT + `rtw89_8851bu` in-tree) — o in-tree assumiu ao mudar de porta e derreteu o USB (crash). FIX: blacklist `rtw89_8851bu` em `/etc/modprobe.d/90-blacklist-rtw89-8851bu.conf`; OOT fica sempre. Perfil NM `ZON-5330_Sala` com `band a` (5GHz only) + `bssid 38:8B:59:E2:38:5A` — mata o flap 2.4GHz.
- **USB autosuspend = inimigo #1:** dormia o dongle (flap), o rato Logitech (lag de wake-up no 1º movimento) e periféricos. FIX: regras udev `/etc/udev/rules.d/91-hid-no-autosuspend.rules` (classe HID) + `90-logitech-no-autosuspend.rules` (046d:c534). Padrão: desativar autosuspend em periféricos/dongles.
- **Áudio BT AirPods Pro 2:** codec AAC nativo (mais estável que SBC-XQ nesta stack). FIXes: config WirePlumber em `~/.config/wireplumber/wireplumber.conf.d/` (50-bluez-codecs.conf + 51-airpods-aac.conf) + **patch do librepods** (omapods) em `daemon/media/profilechoice.hpp` — ranking por prioridade PipeWire (AAC 131 > SBC 130) em vez de bitrate bruto (SBC 328 > AAC 256). Rebuild: `cmake -S daemon -B daemon/build -G Ninja && cmake --build && cmake --install --prefix ~/.local`; `systemctl --user restart librepods`.
- **Patch protegido por hook:** `~/.config/omarchy/hooks/post-update.d/reapply-librepods-patch.hook` reaplica+recompila+reinicia o librepods após `omarchy plugin update`. Fork: `aamsilva/omarchy-pods`.
- **DNS:** systemd-resolved com DoT (`/etc/systemd/resolved.conf.d/dot.conf` — NOTA: é `resolved.conf.d`, não `resolved.conf.d`... na verdade o caminho correto é `/etc/systemd/resolved.conf.d/`). DoT é fallback; router é primário (DHCP).
- **Monitor de saúde:** `~/Work/omarchy-config/system-experiments/metric.py` (SCORE 0-100) corre cada 30min via timer `omarchy-health.timer`, notifica se <80; log em `~/.local/state/omarchy-health.log`. Baseline ~85-95.

## Framework AutoResearch (karpathy/autoresearch aplicado ao sistema)

`~/Work/omarchy-config/system-experiments/`: `program.md` (regras: 1 mudança/vez, métrica única, validação em uso real, git ratchet) + `metric.py` + `results.tsv`. Princípio: nunca empilhar fixes; cada mudança é experiência com baseline+rollback.

## Atalhos/UX

- **opencodemini** (`~/.local/share/applications/opencodemini.desktop` → `~/.local/bin/opencodemini`): abre `opencode attach http://100.74.228.17:4096 -p <pass>` (servidor opencode no Mac Mini augustosilva via Tailscale, porta 4096, sem `--token`, pass em `~/.config/opencode/.secrets.env` no remoto). Menu Omarchy lê DesktopEntries. NOTA: `omarchy-launch-or-focus-tui` exige ARGUMENTOS SEPARADOS, não string única — usar wrapper script.
- Teclado **MX Keys S** está no receiver Logitech (canal 3), NÃO BT (BT pair frágil por endereço privado rotativo). Layout **pt** definido em `~/.config/hypr/input.lua` (`hl.config({ input = { kb_layout = "pt" } })`).
- **BT/AirPods lições:** (1) o scan LE do rádio Realtek pode ficar "preso" (reporta Discovering:yes mas não devolve nada — nem o teclado ao lado); não confundir com o dispositivo não estar a transmitir — o BR/EDR connect pode funcionar mesmo com o scan morto. (2) Um `omarchy restart shell` / scans intensivos + o MX Keys a retentar BT agressivamente podem stressar o rádio combo. (3) Emparelhar AirPods requer um AGENT registado (`bluetoothctl agent KeyboardOnly` + `default-agent` via `~/.config/opencode`... na prática `systemd-run --user --unit=btagent bash -c 'exec bluetoothctl --timeout 900 agent KeyboardOnly'`) — sem agent, o pair falha com `AuthenticationRejected`. (4) Se o pair der `InProgress`, há operação concorrente (ex: MX Keys) a saturar o rádio. (5) AirPods perdem o par do storage do bluetoothd (`/var/lib/bluetooth/<ctrl>/`) se saírem de alcance muito tempo; o MAC BR/EDR (14:28:76:B1:5A:93) é estável mesmo com endereço LE rotativo.
- **AirPods PAR PERDIDO → erro `AuthenticationRejected` (PADRÃO + FIX):** sintomas = `bluetoothctl info` mostra `Paired:no, Connected:yes`, device liga mas **sem sink de áudio**; pair falha com `AuthenticationRejected`; o widget shell pode logar "No discovery started". CAUSA = entrada stale no storage do bluetoothd com `Trusted=false` e **sem LinkKey** (par anterior perdido; A2DP não ativa sem encriptação). FIX (ordem): (1) `bluetoothctl remove 14:28:76:B1:5A:93`; (2) agent ativo `NoInputNoOutput` p/ AirPods (Just Works) via `systemd-run --user --unit=btagent bash -c 'exec bluetoothctl --timeout 900 agent NoInputNoOutput'`; (3) `bluetoothctl pair <mac>` → "Pairing successful"; (4) `bluetoothctl trust <mac>`; (5) `systemctl --user restart wireplumber`; (6) `pactl set-card-profile bluez_card.<mac> a2dp-sink` (AAC, não sbc); verificar `pw-dump` codec=aac. Se ainda sem sink, ver se o widget BT da shell ("No discovery started") está a perturbar o monitor bluez do WP.

## LIÇÕES APRENDIDAS (auto-memorizar — ler sempre)

**REGRAS DE MEMORIZAÇÃO (obrigatório):**
1. No FIM de cada sessão, gravar as lições com: `omarchy-memorize "<lição>"` (commits automático)
2. Sempre que algo correr MAL e for resolvido → adicionar a "Que correu MAL" e ao skill `system-ops` o FIX
3. Sempre que algo correr BEM → adicionar a "Que correu BEM"
4. Todo fix reutilizável vira passo-a-passo no skill `system-ops` (procedimento acionável)
5. NUNCA terminar uma sessão sem memorizar e fazer push (`git -C ~/Work/omarchy-config push`)

### Que correu MAL (nunca repetir)
1. **Empilhar fixes = não saber a causa.** A noite de 26/08 empilhei 6 mudanças; quando o dongle crashou, não soubemos qual era a culpada. → AutoResearch: UMA mudança por vez.
2. **Dois drivers para o mesmo chip USB = corrida de bind que derrete o barramento.** Ao mover o dongle para outra porta, o in-tree `rtw89_8851bu` assumiu e matou o USB. → blacklist sempre o driver secundário.
3. **`omarchy-launch-or-focus-tui` NÃO aceita string única** — passa o comando como argumentos separados (usar wrapper script).
4. **`gh auth` não persiste token se o `timeout` do tool matar o processo** durante o device-flow. → correr sem timeout curto, em background com log.
5. **Caminho do drop-in systemd-resolved é `/etc/systemd/resolved.conf.d/`** (com "d"), não `resolved.conf.d` — perdi 5min nisto.
6. **`omarchy bar set <id> show '[...]'` grava string** e o Argus ignora (exige array real) — editar shell.json diretamente.

### Que correu BEM (manter/replicar)
1. **Blacklist do driver concorrente + pin 5GHz/BSSID** eliminou flap e crash do WiFi.
2. **Desativar USB autosuspend em periféricos** resolveu lag do rato e flap do dongle (regra udev 91-hid + 90-logitech).
3. **Patch librepods (AAC) + hook post-update** = áudio BT estável e auto-cicatrizante.
4. **Framework AutoResearch** (metric.py + program.md + results.tsv + git ratchet) disciplina as mudanças.
5. **Monitor de saúde 30min** (timer + notificação se <80) deteta problemas antes do utilizador.
6. **SSH para GitHub** (em vez de token expirável) + keyring = backup sempre fazível.
7. **Backup de tudo em ~/Work/omarchy-config** (configs, incidentes, hooks, patches) — um único repo de verdade.
8. **Atalho opencodemini** via DesktopEntry + wrapper = ligação fiável ao Mac Mini.

### Padrão de decisão
- Antes de mudar hardware/rede/drivers: garantir **rollback imediato** e **rede alternativa** à mão.
- Medir ANTES e DEPOIS com `metric.py`; só aceitar melhoria.
- Documentar cada experiência em `results.tsv` + commit (ratchet).

### Que correu BEM (auto)
- Voxtype dictation PT com large-v3-turbo (Vulkan GPU) + SUPER+X
