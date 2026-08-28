#!/usr/bin/env python3
"""Sistema health metric 0-100 (escala única p/ loop autoresearch).
Convenção karpathy: uma métrica só, comparável entre runs, honesta.
Penaliza: latência, perda de pacotes, beacon loss, erros de kernel, temp alta."""
import subprocess, re, os, time

def _run(cmd, **kw):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15, **kw).stdout
    except Exception: return ""

def main():
    score = 100.0
    notes = []

    # 1. Ligação WiFi (penalidade principal — foi o foco)
    out = _run("iw dev wlp3s0f0u1i2 link 2>/dev/null || iw dev wlp32s0f3u1i2 link 2>/dev/null")
    m = re.search(r'signal: (-?\d+)', out)
    if m:
        sig = int(m.group(1))
        if sig >= -50: s = 0
        elif sig >= -60: s = 5
        elif sig >= -70: s = 15
        elif sig >= -80: s = 30
        else: s = 50
        score -= s; notes.append(f"sinal={sig}dBm(-{s})")
    else:
        score -= 60; notes.append("SEM LIGACAO WIFI(-60)")

    # 2. Perda de pacotes / latência (ping gateway)
    p = _run("ping -c 8 -W 2 192.168.86.1 2>/dev/null | tail -2")
    if 'packet loss' in p:
        loss = int(re.search(r'(\d+)% packet loss', p).group(1))
        avg = float(re.search(r'= [\d.]+/([\d.]+)/', p).group(1)) if re.search(r'= [\d.]+/([\d.]+)/', p) else 99
        score -= loss * 3
        if avg > 50: score -= 20; notes.append(f"latencia={avg:.0f}ms")
        notes.append(f"loss={loss}% lat={avg:.0f}ms")
    else:
        score -= 40; notes.append("ping falhou(-40)")

    # 3. Beacon loss recente (flap WiFi)
    bl = _run("journalctl -u wpa_supplicant --since '-15 min' --no-pager 2>/dev/null | grep -c BEACON-LOSS")
    bl = int(bl or 0)
    if bl > 0: score -= min(30, bl * 2); notes.append(f"beacon_loss={bl}(-{min(30,bl*2)})")

    # 4. Erros de kernel recentes (usb/driver/gpu)
    ke = _run("journalctl -k --since '-15 min' --no-pager 2>/dev/null | grep -cE 'usb .*error|error -110|amdgpu.*(reset|timeout)|rtl8851.*fail'")
    ke = int(ke or 0)
    if ke > 0: score -= min(30, ke * 5); notes.append(f"kernel_err={ke}(-{min(30,ke*5)})")

    # 5. Temperatura CPU
    t = _run("sensors 2>/dev/null | grep -oE 'Tctl:.*[+-][0-9]+' | grep -oE '[0-9]+' | head -1")
    if t:
        tc = int(t)
        if tc > 80: score -= 20; notes.append(f"temp={tc}C")
        elif tc > 70: score -= 5; notes.append(f"temp={tc}C")

    # 6. BT áudio ativo com codec AAC
    codec = _run("pw-dump 2>/dev/null | grep -A0 bluez_output | head -1") or _run("pactl list cards 2>/dev/null | grep 'Active Profile'")
    if 'a2dp-sink-sbc' in codec: score -= 10; notes.append("codec=SBC(não AAC)")

    # 7. AirPods paired mas sem sink A2DP (par perdido no firmware, mas ainda ligado)
    ap = _run("bluetoothctl info 14:28:76:B1:5A:93 2>/dev/null")
    ap_paired = 'Paired: yes' in ap
    ap_connected = 'Connected: yes' in ap
    ap_has_sink = _run("pactl list sinks 2>/dev/null | grep -c bluez_output.14_28_76")
    ap_has_sink = int(ap_has_sink or 0)
    if ap_paired and ap_connected and ap_has_sink == 0:
        score -= 15; notes.append("AirPods sem sink A2DP(-15)")
    elif ap_connected and not ap_paired:
        score -= 10; notes.append("AirPods par perdido(-10)")

    # 8. Agente BT persistente ativo (sem agente -> pair falha AuthenticationRejected)
    bt_agent = _run("systemctl --user is-active bt-agent.service 2>/dev/null").strip()
    if bt_agent != "active":
        score -= 10; notes.append("bt-agent inativo(-10)")

    score = max(0, int(score))
    print(f"SCORE={score} {' '.join(notes)}")
    return score

if __name__ == "__main__":
    main()