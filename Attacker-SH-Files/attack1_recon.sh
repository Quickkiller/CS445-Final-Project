#!/bin/bash
# attack1_recon.sh - Network reconnaissance against an unknown internal network.
#
# Demonstrates 4 progressive scan styles:
#   (a) Sweep BOTH internal subnets (DMZ 192.168.8.0/24, Internal 192.168.4.0/24)
#       The attacker doesn't know in advance where targets live, so probes both.
#   (b) Fast TCP SYN scan against each discovered host (honeypot + employee).
#   (c) Service version + OS fingerprinting on both.
#   (d) Stealth / evasion scan against the EMPLOYEE PC: slow timing,
#       fragmentation, decoys i.e, the "advanced attacker" demo.
#
# Why this is in the threat model:
#   Reconnaissance is the precondition for every targeted attack. With a DMZ
#   present, the FIRST scan that crosses into 192.168.8.0/24 is high-confidence
#   evidence of intrusion so no legitimate external user would have business there.
#
#   The first three scans should be detected/throttled by the blue team's
#   defenses; the fourth (stealth scan against the employee PC) is designed
#   to slip under the IDS threshold.

source "$(dirname "$0")/config.sh"
require_root

OUT="$EVIDENCE_DIR/attack1_recon_$TIMESTAMP"
mkdir -p "$OUT"

banner "ATTACK 1 - NETWORK RECONNAISSANCE"
echo "DMZ subnet      : $DMZ_SUBNET       (honeypot @ $HONEYPOT_IP)"
echo "Internal subnet : $INTERNAL_SUBNET  (employee @ $EMPLOYEE_IP)"
echo "Evidence dir    : $OUT"
echo

# --- (a) Host discovery across both internal subnets ------------------------
step "Phase A1: ICMP sweep of DMZ subnet $DMZ_SUBNET"
nmap -sn "$DMZ_SUBNET" -oN "$OUT/a1_dmz_discovery.txt" \
    | tee "$OUT/a1_dmz_discovery_console.txt"
ok "Saved: a1_dmz_discovery.txt"
echo

step "Phase A2: ICMP sweep of Internal subnet $INTERNAL_SUBNET"
nmap -sn "$INTERNAL_SUBNET" -oN "$OUT/a2_internal_discovery.txt" \
    | tee "$OUT/a2_internal_discovery_console.txt"
ok "Saved: a2_internal_discovery.txt"
echo

# --- (b) TCP SYN scan against BOTH hosts -----------------------------------
step "Phase B1: TCP SYN scan, ports 1-1000, against the HONEYPOT ($HONEYPOT_IP)"
step "(Cowrie advertises SSH:22 / Telnet:23 -- looks like easy prey)"
step "(Expected: triggers Snort SID 1000001 AND blue team's honeypot alert)"
nmap -sS -p 1-1000 -T4 "$HONEYPOT_IP" -oN "$OUT/b1_honeypot_syn_scan.txt" \
    | tee "$OUT/b1_honeypot_syn_scan_console.txt"
ok "Saved: b1_honeypot_syn_scan.txt"
echo

step "Phase B2: TCP SYN scan, ports 1-1000, against the EMPLOYEE PC ($EMPLOYEE_IP)"
nmap -sS -p 1-1000 -T4 "$EMPLOYEE_IP" -oN "$OUT/b2_employee_syn_scan.txt" \
    | tee "$OUT/b2_employee_syn_scan_console.txt"
ok "Saved: b2_employee_syn_scan.txt"
echo

# --- (c) Service / OS detection -------------------------------------------
step "Phase C: Service version + OS fingerprint on both hosts"
nmap -sV -O -p 22,23,80,443,3389,445 "$HONEYPOT_IP" \
     -oN "$OUT/c1_honeypot_service_os.txt" | tee "$OUT/c1_honeypot_service_os_console.txt"
ok "Saved: c1_honeypot_service_os.txt"
nmap -sV -O -p 22,80,443,3389,445 "$EMPLOYEE_IP" \
     -oN "$OUT/c2_employee_service_os.txt" | tee "$OUT/c2_employee_service_os_console.txt"
ok "Saved: c2_employee_service_os.txt"
echo

# --- (d) Stealth scan against the EMPLOYEE PC -----------------------------
step "Phase D: Stealth scan -- slow timing (-T1), fragmented (-f), with decoys"
step "Targeting the EMPLOYEE PC -- this is the real prize. The honeypot is the noise."
step "This phase is designed to evade the IDS threshold of 20 SYNs/5s."
warn "Phase D is intentionally slow (~3-5 minutes). Let it run."
nmap -sS -T1 -f -D RND:5 -p 22,80,443,3389 "$EMPLOYEE_IP" \
     -oN "$OUT/d_employee_stealth_scan.txt" | tee "$OUT/d_employee_stealth_scan_console.txt"
ok "Saved: d_employee_stealth_scan.txt"
echo

ok "Recon attack complete. Evidence in: $OUT"
echo
echo "For your report, screenshot the contents of:"
echo "  - $OUT/a1_dmz_discovery.txt          (honeypot found in DMZ)"
echo "  - $OUT/a2_internal_discovery.txt     (employee found in internal LAN)"
echo "  - $OUT/b1_honeypot_syn_scan.txt      (SSH/Telnet on honeypot looks juicy)"
echo "  - $OUT/b2_employee_syn_scan.txt      (employee PC -- the real target)"
echo "  - $OUT/d_employee_stealth_scan.txt   (still works under IDS threshold)"
echo
warn "KEY POINT for your report:"
warn "  The attacker probes BOTH internal subnets. The DMZ honeypot is"
warn "  designed to look more attractive (open SSH/Telnet, weak banner)."
warn "  A naive attacker dives in and trips the wire; an advanced attacker"
warn "  who's noticed the deception routes around it -- which is what"
warn "  phase D demonstrates by scanning the employee PC slowly enough"
warn "  to evade the IDS threshold."
