
#!/bin/bash
#===============================================================================
# clock_diag.sh - Comprehensive clock & NTP diagnostic for physical Linux hosts
#
# Purpose : Diagnose extreme clock drift (e.g. +62,911 ppm) - determines whether
#           the problem is local (clocksource/TSC/firmware) or upstream (bad NTP
#           source), and collects all evidence in one report.
#
# Usage   : ./clock_diag.sh [reference_ntp_server]
#           Optional arg: an INDEPENDENT NTP server (not the current source!)
#           for the drift comparison test, e.g.:
#           ./clock_diag.sh ntp1.hq.il.leumi
#
# Safe    : READ-ONLY. Makes no configuration changes.
# Runtime : ~2.5 minutes (includes a 120s drift measurement window)
#===============================================================================

REFSERVER="$1"
OUT="/tmp/clock_diag_$(hostname -s)_$(date +%Y%m%d_%H%M%S).txt"

# --- helpers ------------------------------------------------------------------
line()    { echo "===============================================================================" ; }
section() { echo ""; line; echo "### $1"; line; }
run()     { echo ""; echo "--- CMD: $*"; eval "$@" 2>&1; }
have()    { command -v "$1" >/dev/null 2>&1; }

exec > >(tee "$OUT") 2>&1

line
echo " CLOCK DIAGNOSTIC REPORT"
echo " Host       : $(hostname)"
echo " Date       : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " Kernel     : $(uname -r)"
echo " Report file: $OUT"
line

#-------------------------------------------------------------------------------
section "1. HARDWARE / FIRMWARE IDENTIFICATION"
#-------------------------------------------------------------------------------
if have dmidecode; then
    run "dmidecode -s system-manufacturer"
    run "dmidecode -s system-product-name"
    run "dmidecode -s bios-vendor"
    run "dmidecode -s bios-version"
    run "dmidecode -s bios-release-date"
else
    echo "dmidecode not installed - falling back to sysfs"
    run "cat /sys/class/dmi/id/product_name /sys/class/dmi/id/bios_version 2>/dev/null"
fi
run "lscpu | grep -iE 'model name|socket|hypervisor|numa node\(s\)|cpu\(s\):'"
echo ""
echo ">>> INTERPRETATION: If this is Cisco UCS, check for known TSC errata"
echo ">>> (same family as your previous UCS/HPET case)."

#-------------------------------------------------------------------------------
section "2. CLOCKSOURCE STATE"
#-------------------------------------------------------------------------------
run "cat /sys/devices/system/clocksource/clocksource0/current_clocksource"
run "cat /sys/devices/system/clocksource/clocksource0/available_clocksource"
run "cat /proc/cmdline"
echo ""
echo ">>> INTERPRETATION:"
echo ">>>   current=tsc + watchdog errors below  => TSC unstable, switch to hpet"
echo ">>>   clocksource= already on cmdline      => someone pinned it before"

#-------------------------------------------------------------------------------
section "3. KERNEL LOG - CLOCKSOURCE / TSC EVENTS"
#-------------------------------------------------------------------------------
run "dmesg -T 2>/dev/null | grep -iE 'clocksource|tsc|hpet' | tail -50"
echo ""
echo ">>> RED FLAGS to look for above:"
echo ">>>   'Marking clocksource tsc as unstable'"
echo ">>>   'clocksource watchdog' / 'wd-tsc read delay'"
echo ">>>   'TSC found unsynchronized' / 'check_tsc_sync'"
echo ">>>   'tsc: Fast TSC calibration' with a wrong MHz value (see section 4)"

#-------------------------------------------------------------------------------
section "4. TSC CALIBRATION AT BOOT"
#-------------------------------------------------------------------------------
run "dmesg -T 2>/dev/null | grep -iE 'tsc.*(calibrat|MHz|refined)' "
run "grep -m1 'cpu MHz' /proc/cpuinfo"
run "grep -m1 'model name' /proc/cpuinfo"
echo ""
echo ">>> INTERPRETATION: Compare kernel's calibrated TSC MHz vs the CPU's"
echo ">>> nominal frequency in the model name. A ~6% mismatch would exactly"
echo ">>> explain a ~62,911 ppm drift (constant, one-directional)."

#-------------------------------------------------------------------------------
section "5. SMI / FIRMWARE INTERFERENCE"
#-------------------------------------------------------------------------------
if have turbostat; then
    echo "Sampling SMI counters for 10 seconds..."
    run "timeout 15 turbostat --quiet --show SMI,CPU --interval 5 --num_iterations 2"
    echo ""
    echo ">>> INTERPRETATION: Non-trivial SMI counts (hundreds+/interval) ="
    echo ">>> BIOS stealing time from the kernel. Fix = BIOS update / disable"
    echo ">>> aggressive power management."
else
    echo "turbostat not installed (kernel-tools package). Trying MSR fallback..."
    if have rdmsr; then
        run "rdmsr -a 0x34"   # MSR_SMI_COUNT
    else
        echo "msr-tools not installed either. SKIPPING SMI check."
        echo "To enable: yum install kernel-tools  (or msr-tools + modprobe msr)"
    fi
fi

#-------------------------------------------------------------------------------
section "6. CURRENT CHRONY STATE"
#-------------------------------------------------------------------------------
run "chronyc tracking"
run "chronyc sources -v"
run "chronyc sourcestats -v"
run "chronyc ntpdata 2>/dev/null | head -40"
run "grep -vE '^\s*(#|$)' /etc/chrony.conf"
run "cat /var/lib/chrony/drift 2>/dev/null"
echo ""
echo ">>> INTERPRETATION: drift file caps at +/-500000 ppb internally; a huge"
echo ">>> stored value means chrony has been fighting this for a while."

#-------------------------------------------------------------------------------
section "7. NTP PATH QUALITY TO CURRENT SOURCE"
#-------------------------------------------------------------------------------
CURSRC=$(chronyc -n sources 2>/dev/null | awk '/^\^|^~|^\?/ {print $2; exit}')
# fallback: parse any line with an IP-ish 2nd field
[ -z "$CURSRC" ] && CURSRC=$(chronyc -n sources 2>/dev/null | awk 'NR>3 {print $2; exit}')
if [ -n "$CURSRC" ]; then
    echo "Current source: $CURSRC"
    run "ping -c 5 -i 0.3 $CURSRC"
else
    echo "Could not parse current source from chronyc."
fi

#-------------------------------------------------------------------------------
section "8. DECISIVE TEST: LOCAL DRIFT MEASUREMENT (120 seconds)"
#-------------------------------------------------------------------------------
echo "Measuring wall-clock drift against an independent reference over 120s."
echo "At +62,911 ppm you should gain ~7.5 seconds in 2 minutes if LOCAL."
echo ""

measure_offset() {
    # $1 = server ; prints offset in seconds or 'NA'
    local srv="$1" off=""
    if have chronyd; then
        off=$(chronyd -Q -t 5 "server $srv iburst maxsamples 1" 2>&1 \
              | grep -oE 'offset [-+0-9.]+' | awk '{print $2}' | head -1)
    fi
    if [ -z "$off" ] && have ntpdate; then
        off=$(ntpdate -q "$srv" 2>/dev/null | grep -oE 'offset [-+0-9.]+' \
              | awk '{print $2}' | head -1)
    fi
    echo "${off:-NA}"
}

if [ -n "$REFSERVER" ]; then
    echo "Reference server: $REFSERVER"
    OFF1=$(measure_offset "$REFSERVER")
    echo "T+0s   offset vs $REFSERVER : ${OFF1} s"
    echo "Sleeping 120s..."
    sleep 120
    OFF2=$(measure_offset "$REFSERVER")
    echo "T+120s offset vs $REFSERVER : ${OFF2} s"
    if [ "$OFF1" != "NA" ] && [ "$OFF2" != "NA" ]; then
        DRIFT=$(awk -v a="$OFF1" -v b="$OFF2" 'BEGIN{printf "%.6f", b-a}')
        PPM=$(awk -v d="$DRIFT" 'BEGIN{printf "%.0f", (d/120)*1000000}')
        echo ""
        echo ">>> RESULT: drift over 120s = ${DRIFT}s  =>  ~${PPM} ppm"
        echo ">>> ~60000+ ppm  => LOCAL clock problem (clocksource/TSC/firmware)"
        echo ">>> ~0-100  ppm  => local clock OK; NTAS107777AHV is a FALSETICKER"
    else
        echo ">>> Could not query reference server (firewall/UDP123 blocked?)."
    fi
else
    echo "No reference server given - falling back to CLOCK_MONOTONIC_RAW test."
    echo "(Compares NTP-disciplined clock vs raw hardware counter, 120s)"
    if have python3; then
        python3 - <<'PYEOF'
import time
t0_real = time.clock_gettime(time.CLOCK_REALTIME)
t0_raw  = time.clock_gettime(time.CLOCK_MONOTONIC_RAW)
time.sleep(120)
d_real = time.clock_gettime(time.CLOCK_REALTIME) - t0_real
d_raw  = time.clock_gettime(time.CLOCK_MONOTONIC_RAW) - t0_raw
ppm = (d_real - d_raw) / d_raw * 1e6
print(f"REALTIME elapsed : {d_real:.6f}s")
print(f"RAW      elapsed : {d_raw:.6f}s")
print(f"Divergence       : {ppm:+.1f} ppm (this is chrony's slew, informational)")
print("NOTE: both clocks share the same underlying counter, so this test")
print("cannot detect a miscalibrated TSC by itself - the reference-server")
print("test is the authoritative one. Re-run with a server argument.")
PYEOF
    else
        echo "python3 not available - skipping. Re-run with a reference server arg."
    fi
fi

#-------------------------------------------------------------------------------
section "9. SYSTEM LOAD SANITY (rules out extreme starvation)"
#-------------------------------------------------------------------------------
run "uptime"
run "vmstat 2 3"
run "cat /proc/interrupts | grep -iE 'timer|hpet|LOC' | head -10"

#-------------------------------------------------------------------------------
section "10. SUMMARY / DECISION TREE"
#-------------------------------------------------------------------------------
cat <<'EOF'
Interpret in this order:

[A] Section 8 shows ~60,000 ppm vs independent server
    => LOCAL problem. Go to [B].
    Section 8 shows near-zero drift
    => Local clock is FINE. NTAS107777AHV is a falseticker (it is likely a
       VM on Nutanix with its own broken clock). Fix: replace/augment NTP
       sources in chrony.conf with 3-4 independent bank pool servers.

[B] Section 3 shows 'tsc unstable' / watchdog messages
    => Same class as your UCS case. Fix: clocksource=hpet on kernel cmdline
       (grubby --update-kernel=ALL --args="clocksource=hpet"), reboot,
       then: chronyc makestep. Check vendor firmware advisories.

[C] Section 4 shows TSC calibrated ~6% off from nominal CPU MHz
    => Boot-time miscalibration (firmware/BIOS bug). Fix: BIOS update;
       workaround: clocksource=hpet, or tsc=recalibrate (newer kernels).

[D] Section 5 shows high SMI counts
    => Firmware stealing cycles. Fix: BIOS update, disable aggressive
       C-states/power management in BIOS.

[E] Nothing conclusive
    => Send this report file for analysis: 
EOF
echo "       $OUT"
echo ""
line
echo " DONE. Full report saved to: $OUT"
line
