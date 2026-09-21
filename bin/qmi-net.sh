#!/bin/bash
# qmi-net.sh — QMI data-path helpers shared by start.sh / stop.sh.
# Data call = quectel-CM (background). Attach/detach = ci_ctl_qtel.py (AT+CFUN toggles).
# Safe to source under `set -euo pipefail`.

QMI_ATPORT="${QMI_ATPORT:-/dev/ttyUSB2}"   # modem AT control port
QMI_IFACE="${QMI_IFACE:-wwan0}"
CM_BIN="quectel-CM"
CM_LOG="${CM_LOG:-/var/log/quectel-cm.log}"
CI_CTL="python3 /usr/local/bin/ci_ctl_qtel.py"

# Start exactly one quectel-CM in background, confirm it stays up. $1 = APN/DNN.
qmi_ensure_cm() {
    local apn="$1" i
    if pgrep -x "$CM_BIN" >/dev/null; then
        echo "$CM_BIN already running (pid $(pgrep -x "$CM_BIN" | tr '\n' ' ')) — reusing it"
    else
        echo "Starting $CM_BIN -s $apn -4 (background)"
        nohup "$CM_BIN" -s "$apn" -4 >"$CM_LOG" 2>&1 &
    fi
    # quectel-CM exits at once if the QMI device is busy or a 2nd instance clashes.
    for i in $(seq 1 5); do
        sleep 1
        pgrep -x "$CM_BIN" >/dev/null && return 0
    done
    echo "ERROR: $CM_BIN did not stay up — check $CM_LOG" >&2
    return 1
}

qmi_wup()    { echo "wup (attach) via $QMI_ATPORT"; $CI_CTL "$QMI_ATPORT" wup; }
qmi_detach() { echo "detach via $QMI_ATPORT";       $CI_CTL "$QMI_ATPORT" detach; }

# Poll until the data interface gets an IPv4 (quectel-CM brings it up after attach).
qmi_wait_ip() {
    local i ip
    for i in $(seq 1 40); do
        ip=$(ip -4 -o addr show dev "$QMI_IFACE" 2>/dev/null | awk '{print $4}') || true
        [[ -n "$ip" ]] && { echo "Got IP $ip on $QMI_IFACE after ${i}s"; return 0; }
        sleep 1
    done
    echo "ERROR: no IPv4 on $QMI_IFACE after 40s — check $CM_LOG" >&2
    return 1
}

qmi_stop_cm() {   # only on stop.sh --full
    pgrep -x "$CM_BIN" >/dev/null && { echo "Stopping $CM_BIN"; pkill -x "$CM_BIN"; }
}
