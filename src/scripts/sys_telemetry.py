#!/usr/bin/env python3
"""Lightweight one-shot hardware telemetry snapshot for Anserin System Monitor (Minimal & Smart).
Reads /proc, /sys, df, ps, powerprofilesctl, and optional ping; stores small delta state in XDG_RUNTIME_DIR.
Zero background daemon, zero heavy dependencies.
"""
import glob
import json
import os
import re
import subprocess
import sys
import time

RUN_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "anserin", "sysdata")
STATE_PATH = os.path.join(RUN_DIR, "telemetry_state.json")
os.makedirs(RUN_DIR, exist_ok=True)


def read_text(path, default=""):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read().strip()
    except Exception:
        return default


def run_cmd(cmd, timeout=1.5):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=timeout).strip()
    except Exception:
        return ""


def load_state():
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(st):
    try:
        tmp = STATE_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(st, f)
        os.replace(tmp, STATE_PATH)
    except Exception:
        pass


def fmt_rate(bps):
    if bps >= 1024 * 1024:
        return f"{bps / (1024 * 1024):.1f} MB/s"
    if bps >= 1024:
        return f"{bps / 1024:.0f} KB/s"
    return f"{int(bps)} B/s"


def fmt_peak(bps):
    if bps >= 1024 * 1024:
        return f"{bps / (1024 * 1024):.1f}M"
    if bps >= 1024:
        return f"{bps / 1024:.0f}K"
    return f"{int(bps)}B"


def proc_icon(name):
    n = name.lower()
    if any(k in n for k in ("brave", "chrom", "firefox", "zen", "vivaldi", "edge")):
        return "󰖟"
    if any(k in n for k in ("code", "cursor", "nvim", "vim", "claude", "agy", "node", "python")):
        return "󰨞"
    if any(k in n for k in ("kitty", "foot", "alacritty", "wezterm", "ghostty", "bash", "zsh", "fish")):
        return "󰆍"
    if any(k in n for k in ("hyprland", "quickshell", "xwayland", "waybar")):
        return "󰖲"
    if any(k in n for k in ("spotify", "mpv", "vlc", "pipewire", "wireplumber", "pulse")):
        return "󰎈"
    if any(k in n for k in ("steam", "wine", "proton", "gamescope")):
        return "󰊗"
    if any(k in n for k in ("dolphin", "thunar", "nautilus", "ski")):
        return "󰉋"
    return "󰘚"


def collect_cpu(prev):
    stat = read_text("/proc/stat")
    cur_cores = {}
    total_pct = 0
    for line in stat.splitlines():
        if not line.startswith("cpu"):
            continue
        parts = line.split()
        key = parts[0]
        nums = [int(x) for x in parts[1:9]]
        idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
        tot = sum(nums)
        cur_cores[key] = [idle, tot]

    prev_cores = prev.get("cpu", {})
    per_core = []
    if "cpu" in cur_cores and "cpu" in prev_cores:
        di = cur_cores["cpu"][0] - prev_cores["cpu"][0]
        dt = max(1, cur_cores["cpu"][1] - prev_cores["cpu"][1])
        total_pct = max(0, min(100, round(100.0 * (1.0 - di / dt))))
    idx = 0
    while f"cpu{idx}" in cur_cores:
        k = f"cpu{idx}"
        if k in prev_cores:
            di = cur_cores[k][0] - prev_cores[k][0]
            dt = max(1, cur_cores[k][1] - prev_cores[k][1])
            per_core.append(max(0, min(100, round(100.0 * (1.0 - di / dt)))))
        else:
            per_core.append(total_pct)
        idx += 1

    # Physical core count + average frequency
    phys_ids = set()
    freqs = []
    for line in read_text("/proc/cpuinfo").splitlines():
        if line.startswith("core id"):
            phys_ids.add(line.split(":", 1)[1].strip())
        elif line.startswith("cpu MHz"):
            try:
                freqs.append(float(line.split(":", 1)[1].strip()))
            except Exception:
                pass
    threads = max(1, len(per_core) or (os.cpu_count() or 1))
    phys = max(1, len(phys_ids) if phys_ids else threads // 2 or threads)
    ghz = (sum(freqs) / len(freqs) / 1000.0) if freqs else 0.0
    sub_short = f"{phys}C {threads}T"
    sub = f"{sub_short} · {ghz:.2f} GHz" if ghz > 0 else sub_short

    # Split into two balanced rows for Bento P/E visual bars (cap 8 per row)
    half = max(1, len(per_core) // 2)
    p_cores = per_core[: min(8, half)] if len(per_core) > 1 else per_core
    e_cores = per_core[half : half + 8] if len(per_core) > 1 else []

    return {
        "pct": total_pct,
        "ghz": round(ghz, 2),
        "sub": sub,
        "subShort": sub_short,
        "pCores": p_cores,
        "eCores": e_cores,
        "_state": cur_cores,
    }


def collect_gpus():
    gpus = []
    # 1. Try nvidia-smi first for NVIDIA cards
    nv = run_cmd([
        "nvidia-smi",
        "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
        "--format=csv,noheader,nounits",
    ])
    if nv:
        for line in nv.splitlines():
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 5:
                used = float(parts[3]) / 1024.0
                tot = max(0.1, float(parts[4]) / 1024.0)
                gpus.append({
                    "name": parts[0],
                    "pct": max(0, min(100, int(float(parts[1])))),
                    "temp": int(float(parts[2])),
                    "vramText": f"{used:.1f} / {tot:.1f} GB",
                    "vramFrac": min(1.0, used / tot),
                })

    # 2. Scan /sys/class/drm/card* for AMD / Intel GPUs
    lspci_lines = [l for l in run_cmd(["lspci"]).splitlines() if any(k in l.lower() for k in ("vga", "3d", "display"))]
    seen_slots = set()
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        base = os.path.basename(card)
        if "-" in base:
            continue
        dev = os.path.join(card, "device")
        uevent = read_text(os.path.join(dev, "uevent"))
        slot = ""
        driver = ""
        for line in uevent.splitlines():
            if line.startswith("PCI_SLOT_NAME="):
                slot = line.split("=", 1)[1]
            elif line.startswith("DRIVER="):
                driver = line.split("=", 1)[1]
        if not driver or driver == "nvidia" or (slot and slot in seen_slots):
            continue
        if slot:
            seen_slots.add(slot)

        # Friendly name from lspci
        name = f"{driver.upper()} GPU"
        short_slot = slot[5:] if slot.startswith("0000:") else slot
        for l in lspci_lines:
            if short_slot and short_slot in l:
                m = l.split(":", 2)
                raw_name = m[2].strip() if len(m) >= 3 else l
                raw_name = re.sub(r"\(rev [^)]+\)", "", raw_name).strip()
                raw_name = raw_name.replace("Corporation ", "").replace("Advanced Micro Devices, Inc. ", "")
                name = raw_name[:42]
                break

        # Utilization
        pct = 0
        busy_path = os.path.join(dev, "gpu_busy_percent")
        if os.path.exists(busy_path):
            try:
                pct = max(0, min(100, int(read_text(busy_path, "0"))))
            except Exception:
                pct = 0
        else:
            # Intel i915/xe: use active GPU frequency ratio as lightweight non-root load indicator
            cur_f = read_text(os.path.join(card, "gt_act_freq_mhz")) or read_text(os.path.join(card, "gt_cur_freq_mhz"))
            min_f = read_text(os.path.join(card, "gt_min_freq_mhz"), "300")
            max_f = read_text(os.path.join(card, "gt_max_freq_mhz"), "1050")
            if cur_f.isdigit() and max_f.isdigit():
                c, lo, hi = int(cur_f), int(min_f) if min_f.isdigit() else 300, max(1, int(max_f))
                if hi > lo:
                    pct = max(0, min(100, round(100.0 * max(0, c - lo) / (hi - lo))))

        # Temp from device hwmon or thermal package
        temp = 0
        for tp in glob.glob(os.path.join(dev, "hwmon", "hwmon*", "temp1_input")):
            v = read_text(tp)
            if v.isdigit():
                temp = round(int(v) / 1000.0)
                break
        if temp <= 0:
            # Fallback to SoC package temp for iGPU
            for tz in glob.glob("/sys/class/thermal/thermal_zone*"):
                t_type = read_text(os.path.join(tz, "type")).lower()
                if any(k in t_type for k in ("x86_pkg", "gpu", "acpitz", "soc")):
                    v = read_text(os.path.join(tz, "temp"))
                    if v.isdigit() and 15000 <= int(v) <= 110000:
                        temp = round(int(v) / 1000.0)
                        break

        # VRAM (AMD exposes mem_info_vram_used/total; Intel iGPU uses shared RAM)
        vram_u = read_text(os.path.join(dev, "mem_info_vram_used"))
        vram_t = read_text(os.path.join(dev, "mem_info_vram_total"))
        if vram_u.isdigit() and vram_t.isdigit() and int(vram_t) > 0:
            u_gb = int(vram_u) / (1024 ** 3)
            t_gb = int(vram_t) / (1024 ** 3)
            vram_text = f"{u_gb:.1f} / {t_gb:.1f} GB"
            vram_frac = min(1.0, u_gb / max(0.1, t_gb))
        else:
            vram_text = "Shared RAM"
            vram_frac = pct / 100.0

        gpus.append({
            "name": name,
            "pct": pct,
            "temp": temp,
            "vramText": vram_text,
            "vramFrac": round(vram_frac, 3),
        })

    if not gpus:
        gpus.append({"name": "Integrated GPU", "pct": 0, "temp": 0, "vramText": "Shared", "vramFrac": 0.0})
    return gpus


def collect_disks():
    # NVMe/SATA temperature if available
    disk_temp = 0
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        nm = read_text(os.path.join(hw, "name")).lower()
        if any(k in nm for k in ("nvme", "drivetemp", "sata")):
            v = read_text(os.path.join(hw, "temp1_input"))
            if v.isdigit() and 10000 <= int(v) <= 105000:
                disk_temp = round(int(v) / 1000.0)
                break

    disks = []
    seen = set()
    df_out = run_cmd(["df", "-B1", "--output=source,target,used,size,pcent"])
    for line in df_out.splitlines()[1:]:
        cols = line.split()
        if len(cols) < 5:
            continue
        src, mnt, used_s, size_s, pct_s = cols[0], cols[1], cols[2], cols[3], cols[4]
        if not src.startswith("/dev/"):
            continue
        if mnt.startswith(("/boot", "/efi", "/snap", "/var/lib")):
            continue
        if src in seen:
            continue
        seen.add(src)
        try:
            u_gb = int(used_s) / (1024 ** 3)
            t_gb = max(0.1, int(size_s) / (1024 ** 3))
            pct = max(0, min(100, int(pct_s.rstrip("%"))))
        except Exception:
            continue
        disks.append({
            "mount": mnt,
            "pct": pct,
            "sub": f"{u_gb:.0f}/{t_gb:.0f} GB" if t_gb >= 100 else f"{u_gb:.1f}/{t_gb:.1f} GB",
            "temp": disk_temp,
        })
    disks.sort(key=lambda d: (0 if d["mount"] == "/" else 1, d["mount"]))
    if not disks:
        disks.append({"mount": "/", "pct": 0, "sub": "0/0 GB", "temp": disk_temp})
    return disks


def collect_net(prev, now):
    rx, tx = 0, 0
    for line in read_text("/proc/net/dev").splitlines()[2:]:
        if ":" not in line:
            continue
        iface, rest = line.split(":", 1)
        iface = iface.strip()
        if iface == "lo" or iface.startswith(("docker", "br-", "veth", "virbr")):
            continue
        cols = rest.split()
        if len(cols) >= 9:
            rx += int(cols[0])
            tx += int(cols[8])

    prev_net = prev.get("net") or {}
    dt = max(0.2, now - float(prev_net.get("ts", now - 2.0)))
    down_bps = max(0.0, (rx - int(prev_net.get("rx", rx))) / dt) if prev_net else 0.0
    up_bps = max(0.0, (tx - int(prev_net.get("tx", tx))) / dt) if prev_net else 0.0

    raw_hist = list(prev_net.get("hist") or [0.0] * 16)[-15:]
    raw_hist.append(down_bps + up_bps)
    peak = max(max(raw_hist), 10240.0)
    norm_hist = [round(min(1.0, v / peak), 3) for v in raw_hist]

    return {
        "downText": fmt_rate(down_bps),
        "upText": fmt_rate(up_bps),
        "peakText": fmt_peak(max(raw_hist)),
        "hist": norm_hist,
        "_state": {"rx": rx, "tx": tx, "ts": now, "hist": raw_hist},
    }


def collect_power():
    raw_prof = run_cmd(["powerprofilesctl", "get"], timeout=1.0).lower()
    prof_map = {"performance": "Performance", "balanced": "Balanced", "power-saver": "Power Saver"}
    profile = prof_map.get(raw_prof, "Balanced")
    has_profiles = raw_prof in prof_map

    watts = 0.0
    status = "AC power"
    bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if bats:
        b = bats[0]
        st = read_text(os.path.join(b, "status"), "")
        p_now = read_text(os.path.join(b, "power_now"))
        c_now = read_text(os.path.join(b, "current_now"))
        v_now = read_text(os.path.join(b, "voltage_now"))
        if p_now.isdigit():
            watts = int(p_now) / 1e6
        elif c_now.isdigit() and v_now.isdigit():
            watts = (int(c_now) * int(v_now)) / 1e12
        if st == "Discharging":
            status = "Battery discharge"
        elif st == "Charging":
            status = "Charging · AC on"
        elif st == "Full":
            status = "Fully charged · AC"
        elif st:
            status = st
    return {
        "profile": profile,
        "hasProfiles": has_profiles,
        "watts": f"{watts:.1f}" if watts > 0.05 else "—",
        "status": status,
    }


def collect_ping(prev, now, want_ping):
    last_ping = prev.get("ping") or {"ms": -1, "ts": 0}
    if not want_ping and (now - float(last_ping.get("ts", 0))) < 8.0:
        return last_ping
    out = run_cmd(["ping", "-c", "1", "-W", "1", "1.1.1.1"], timeout=1.4)
    m = re.search(r"time=([0-9.]+)\s*ms", out)
    ms = round(float(m.group(1))) if m else -1
    return {"ms": ms, "ts": now}


def collect_procs():
    # Group by comm so multi-process browsers/apps aggregate cleanly
    out = run_cmd(["ps", "-eo", "comm=,nlwp=,pcpu=,rss="], timeout=1.5)
    by_name = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        name = parts[0]
        try:
            thr = int(parts[1])
            cpu = float(parts[2])
            rss_kb = int(parts[3])
        except Exception:
            continue
        if name not in by_name:
            by_name[name] = [0, 0.0, 0]
        by_name[name][0] += thr
        by_name[name][1] += cpu
        by_name[name][2] += rss_kb

    def fmt_mem(kb):
        mb = kb / 1024.0
        if mb >= 1024:
            return f"{mb / 1024.0:.1f}G"
        return f"{mb:.0f}M"

    top_cpu = sorted(by_name.items(), key=lambda kv: -kv[1][1])[:5]
    top_mem = sorted(by_name.items(), key=lambda kv: -kv[1][2])[:5]
    return {
        "topCpu": [
            {"icon": proc_icon(k), "name": k, "threads": str(v[0]), "val": f"{v[1]:.1f}%"}
            for k, v in top_cpu
        ],
        "topMem": [
            {"icon": proc_icon(k), "name": k, "threads": str(v[0]), "val": fmt_mem(v[2])}
            for k, v in top_mem
        ],
    }


def main():
    now = time.time()
    prev = load_state()
    want_ping = "--ping" in sys.argv
    cpu = collect_cpu(prev)
    net = collect_net(prev, now)
    ping = collect_ping(prev, now, want_ping)
    procs = collect_procs()
    payload = {
        "cpu": {k: v for k, v in cpu.items() if k != "_state"},
        "gpus": collect_gpus(),
        "disks": collect_disks(),
        "net": {k: v for k, v in net.items() if k != "_state"},
        "power": collect_power(),
        "pingMs": ping["ms"],
        "topCpuProcs": procs["topCpu"],
        "topMemProcs": procs["topMem"],
    }
    save_state({"cpu": cpu["_state"], "net": net["_state"], "ping": ping})
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
