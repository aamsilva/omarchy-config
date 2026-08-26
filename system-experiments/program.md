# SYSTEM-AUTORESEARCH — programa (estilo karpathy/autoresearch)

O objetivo é otimizar ESTE sistema (Omarchy/Hyprland/AMD/USB-WiFi-BT) de forma
disciplinada: um loop autónomo onde cada alteração é uma EXPERIÊNCIA medida,
aceite apenas se melhorar a métrica, e onde o git é a memória (ratchet).

## Arquitetura (espelho do autoresearch)

| Papel autoresearch | Aqui |
|--------------------|------|
| `train.py` (mutável) | configs pequenas: `udev/`, `wireplumber/`, `NetworkManager/`, `systemd/` neste repo |
| `prepare.py` (bloqueado) | o hardware/drivers base — NÃO mudar à toa |
| `program.md` (este) | regras do loop |
| métrica escalar | `metric.py` → valor 0-100 |
| validação held-out | uso real durante ≥1h / 24h, NÃO o momento da mudança |
| git ratchet | só commits que melhoram ou revertem |

## Regras do loop

1. **UMA mudança por experimento.** Nunca empilhar fixes (a noite de 26/08 quebrou
   esta regra e não soubemos o que causou o crash do dongle).
2. **Medir ANTES e DEPOIS** com `metric.py`. Sem baseline, não é experiência.
3. **Manter só o que melhora.** Se piorar ou ficar igual, reverter e registar.
4. **Orçamento de tempo fixo** por mudança: 1h de uso real antes de decidir.
5. **Toda mudança = commit descritivo** + linha em `results.tsv` (aceite/revertida).
6. **Priorizar estabilidade > velocidade.** Um sistema que não crasha > um que é 5% mais rápido.
7. **Reversão sempre disponível.** Antes de cada experimento, garantir rollback imediato.

## Classes de mudança (ordem de confiança)
- A: udev/sysfs (hardware PM) — ALTA confiança se for sleep/wake
- B: configs de serviço (wireplumber, NM) — MÉDIA, testar bem
- C: drivers/módulos (blacklist) — ALTA mas com risco, rollback fácil
- D: hardware físico (portas USB) — só documental, não automatizável