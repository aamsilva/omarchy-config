# Integração TV TCL ↔ Omarchy (HDMI1)

Integração do Remote Control Unit (RCU) da TV TCL 4K com o Omarchy quando o input
HDMI1 (o PC) está ativo, para uma experiência "TV-like" (navegar o PC com o comando
da TV, estilo Kodi/Android TV).

## Hardware em causa
- **TV TCL 4K** — "Technical Concepts Ltd Beyond TV" (vendor EDID `Pl`), 3840x2160@60,
  modo Game Mode, display 8-bit XRGB8888. Liga ao Omarchy via **HDMI-A-2** da GPU.
- **GPU AMD Radeon RX 570/580 (Polaris/Ellesmere)** — 2 portas HDMI (HDMI-A-1, HDMI-A-2).
- **RCU (Remote Control Unit)** TCL — envia **IR** (protocolo nikai/NEC) para a TV.

## Mapa de protocolos (investigação 2026-09-04)

TV na rede: **`192.168.86.55`** (MAC `78:93:c3:2f:46:69`).

| Porta | Protocolo | Direção | Uso |
|-------|-----------|---------|-----|
| `5555` | ADB | Omarchy → TV | Controlo total: `input keyevent`, intents, power, input-switch, status |
| `6466/6467` | Android TV Remote v2 | Omarchy → TV | Controlo TV (D-pad, media, volume, power) com pairing por certificado — sem ADB |
| `8008/8009` | TCL RKU + Chromecast | Omarchy → TV | Protocolo remoto legado TCL / Cast (receiver) |
| `9000` | Chromecast/DIAL | Omarchy → TV | Lançar apps, deep links |
| HDMI-CEC | — | **IMPOSSÍVEL na Polaris** | GPU AMD expõe CEC **só via túnel DP** (adaptador DP→HDMI Parade PS175/176/186 ou MegaChips 2900), **nunca em HDMI direto** (connector HDMI-A-*). Por isso não há `/dev/cec*` nem controlo CEC possível por esta via. |

### CEC: porque NÃO é possível nesta GPU (facto técnico)
O módulo `cec` está carregado (usado pelo `drm_display_helper`/`amdgpu`), mas **não
existe `/dev/cec*`** porque a Polaris não roteia o pino CEC do HDMI para o OS.
AMDGPU suporta CEC **apenas via "CEC-Tunneling-over-AUX"** em ligações **DisplayPort**
(ver archwiki + kernel docs). O nosso PC usa HDMI direto → sem CEC possível.
Para CEC seria preciso um **adaptador DP→HDMI com pino CEC ligado** (Parade PS175/176/186,
MegaChips 2900) OU um dongle USB Pulse-Eight. Ambas = hardware adicional.

## Direção escolhida pelo utilizador: relay via ADB (sem hardware novo)
O RCU envia IR → TV. Para as teclas do RCU chegarem ao Omarchy, usamos a TV como
ponte via **ADB** (porta 5555, confirmada aberta):

```
[RCU físico] --IR--> [TV TCL] --ADB shell (espelha keyevents)--> [rede TCP] --> [Omarchy daemon] --wtype/hyprctl--> [Hyprland]
```

### Comunicação (reverse direction do ChromeOS/ATV)
1. **Omarchy** liga à TV por ADB: `adb connect 192.168.86.55:5555`
2. Na TV corre-se um serviço que **espelha os keyevents do RCU** (gerados quando o
   RCU aperta botões e a TV os converte em keycodes Android) para o PC via TCP.
3. Omarchy tem um **daemon** que liga nessa porta e **mapeia os keycodes Android →
   ações Wayland/Hyprland** (`wtype`, `hyprctl dispatch`, atalhos).

> **Limitação documentada:** o processo na TV é frágil a reboots da TV e a
> background-kill do Android (o shell pode ser morto). Para robustez total recomenda-se
> receptor USB IR no PC (códigos IR TCL conhecidos, protocolo nikai — ver abaixo).

## Códigos IR TCL (protocolo nikai/NEC) — para receptor USB IR do PC
Decodificados com IRremoteESP8266 (gist tardhiansyah):
```
power = 0xD5F2A      nav_up = 0xA6F59      back = 0xD8F27
mute  = 0xC0F3F      nav_down = 0xA7F58    home = 0xF7F08
setting = 0x30FCF    nav_right = 0xA8F57   antenna = 0xE5F1A
bookmark = 0x9EF61   nav_left = 0xA9F56    input = 0x5CFA3
g_assistant = 0xA3F5C nav_center = 0xBFF4  menu = 0x13FEC
volume_up = 0xD0F2F  channel_up = 0xD2F2D
volume_down = 0xD1F2E channel_down = 0xD3F2C
task_switcher = 0x83F7C
```
Envio exemplo: `irsend.sendNikai(...)` ou LIRC/`ir-keytable` com o map apropriado.

## Códigos ADB keyevent (Android) — para o relay e para controlo da TV
Usados com `adb shell input keyevent <code>`:
```
KEYCODE_DPAD_UP 19      KEYCODE_DPAD_DOWN 20    KEYCODE_DPAD_LEFT 21
KEYCODE_DPAD_RIGHT 22   KEYCODE_DPAD_CENTER 23  KEYCODE_BACK 4
KEYCODE_HOME 3          KEYCODE_MENU 82         KEYCODE_VOLUME_UP 24
KEYCODE_VOLUME_DOWN 25  KEYCODE_MUTE 91         KEYCODE_POWER 26
KEYCODE_MEDIA_PLAY_PAUSE 85  KEYCODE_MEDIA_NEXT 87  KEYCODE_MEDIA_PREVIOUS 88
KEYCODE_ENTER 66        KEYCODE_TV_POWER 405
KEYCODE_NUMPAD_0..9 = 144..153
```

## Controlo da TV a partir do Omarchy (Omarchy → TV)
### Mudar input HDMI (TCL Google TV) — intent direto, instantâneo
```
adb shell am start -a android.intent.action.VIEW \
  -d "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW15"
```
Mapeamento TCL (TvPassThroughService): HDMI1=HW15, HDMI2=HW16, HDMI3=HW17, HDMI4=HW18.
> NOTA: HW16/17/18 podem não funcionar em todos os firmwares (community HA reporta
> que só HW15 (HDMI1) funciona de forma fiável em alguns modelos C805).

### Alternativa via Android TV Remote v2 (porta 6466/6467, sem ADB)
Protocolo do app Google TV. Pairing por PIN no ecrã + certificados em `~/.config/gtv/`.
Ferramenta CLI: `gtv-remote` (python), lib: `androidtvremote2`. Envia keyevents
DPAD/media/volume/power e intents. Bom fallback se o ADB estiver indisponível.

## Ferramentas Omarchy disponíveis (já instaladas)
- `wtype` — injetar teclado em Wayland (essencial para RCU→Omarchy)
- `xdotool` — alternativo (XWayland)
- `ir-keytable` / `ir-ctl` — ferramentas RC do kernel (para futuro receptor USB IR)
- `hyprctl dispatch` — ações de janela/focus/monitor do Hyprland

## Estrutura do projeto
- `README.md` — este documento (mapa protocolo + arquitetura)
- `scripts/` — daemons e utilitários (a implementar)
- `keys/` — tabelas de mapeamento keycode Android → ações Omarchy

Estado: **arquitetura definida; implementação do relay ADB em curso.**
