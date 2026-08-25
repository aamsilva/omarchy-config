# Omarchy config (aamsilva)

Backup das personalizações do Omarchy (Hyprland + shell).

## Conteúdo

| Ficheiro | Destino | O quê |
|---|---|---|
| `shell.json` | `~/.config/omarchy/shell.json` | Layout da barra: Argus à esquerda; nvme-health no centro junto ao weather |
| `hypr/bindings.lua` | `~/.config/hypr/bindings.lua` | `SUPER+SHIFT+A` → Agent (opencode); `SUPER+CTRL+V` → painel Vitals |

## Plugins instalados

```bash
# Monitor tipo exelban/Stats (CPU/GPU/MEM/DISK/NET/PROC/TEMP, sparklines, alertas)
omarchy plugin add https://github.com/diegopluna/omarchy-argus.git --enable --yes

# SSD/NVMe health — versão patchada minha com suporte SATA melhorado
omarchy plugin add https://github.com/augustosilva/omarchy-nvme-health.git --enable --yes

# Painel btop-style
omarchy plugin add https://github.com/Woogy7/omarchy-vitals.git --enable --yes
```

Argus: o `show` tem de ser array JSON real em shell.json (`omarchy bar set <id> show '[...]'
grava string que o plugin ignora`). Config usada: cpu, cputemp, gputemp, ram, disk, net.

Agente default:

```bash
omarchy default agent opencode
```
