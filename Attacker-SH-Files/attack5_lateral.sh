#!/bin/bash
# attack5_lateral.sh - Lateral movement attempt: DMZ -> Internal network.
#
# This attack is enabled by the team's three-subnet architecture (External,
# DMZ, Internal). After "compromising" the honeypot (phase A of attack 4),
# the attacker assumes they can pivot through the DMZ into the protected
# internal subnet to reach the employee PC.
#
# Why this is in the threat model:
#   Lateral movement is one of the most damaging post-exploitation steps
#   in a real intrusion. A correctly segmented network FORBIDS the DMZ
#   from initiating new connections to the internal LAN, the firewall
#   should drop these probes. Demonstrating this attack provides direct
#   evidence that the blue team's segmentation rule works (or doesn't).
#
# How this script simulates pivot:
#   We don't actually have a shell on the honeypot, but Cowrie sessions
#   are sandboxed anyway. So this script offers two equivalent options:
#
#     1) DEFAULT (works on attacker VM):
#        Add a temporary route via the honeypot, then probe the internal
#        subnet. If the firewall blocks, our probes return no answer; if
#        the firewall is misconfigured, we get responses.
#
#     2) MANUAL (for the demo):
#        SSH into the honeypot's HOST OS (NOT the Cowrie sandbox) and run
#        the equivalent commands from there. Yields cleaner evidence
#        because the source IP is the DMZ host itself.
#
# Either way, what we're TESTING is whether the firewall's FORWARD chain
# drops traffic where src in DMZ and dst in Internal.

source "$(dirname "$0")/config.sh"
require_root

OUT="$EVIDENCE_DIR/attack5_lateral_$TIMESTAMP"
mkdir -p "$OUT"

banner "ATTACK 5 - LATERAL MOVEMENT (DMZ -> INTERNAL)"
echo "Pivot point (compromised) : $HONEYPOT_IP   (in DMZ)"
echo "Target (real prize)       : $EMPLOYEE_IP   (in Internal)"
echo "What we're testing        : firewall blocks DMZ -> Internal forwarding"
echo "Evidence dir              : $OUT"
echo

# --- (a) Direct probe from attacker: baseline -----------------------------
step "Phase A: Baseline -- direct probe from attacker to employee PC"
step "(This is the path the firewall is EXPECTED to allow under controlled rules.)"
nmap -sS -p 22,80,3389 -Pn "$EMPLOYEE_IP" \
     -oN "$OUT/a_direct_attacker_to_employee.txt" \
     | tee "$OUT/a_direct_console.txt"
echo

# --- (b) Simulated pivot via honeypot --------------------------------------
step "Phase B: Add a route to internal subnet via the honeypot"
step "We pretend the honeypot is now under our control and is forwarding for us."

# Save current routes for restoration
ip route show > "$OUT/b_routes_before.txt"

# Add a more-specific route: $EMPLOYEE_IP/32 via $HONEYPOT_IP
# (We'll need the honeypot to actually be reachable for the route to install)
if ip route add "$EMPLOYEE_IP/32" via "$HONEYPOT_IP" 2>"$OUT/b_route_add_error.txt"; then
    ok "Route installed: $EMPLOYEE_IP/32 via $HONEYPOT_IP"
    ROUTE_ADDED=1
else
    warn "Could not install pivot route. The honeypot may not be on a directly"
    warn "reachable subnet from the attacker. Falling back to direct probe with"
    warn "spoofed source IP (less reliable but illustrative)."
    ROUTE_ADDED=0
fi

step "Probing the employee PC through the simulated pivot..."
nmap -sS -p 22,80,3389 -Pn "$EMPLOYEE_IP" \
     -oN "$OUT/b_via_honeypot_probe.txt" \
     | tee "$OUT/b_via_honeypot_console.txt" || true
echo

# Cleanup the route
if [ "$ROUTE_ADDED" = "1" ]; then
    ip route del "$EMPLOYEE_IP/32" via "$HONEYPOT_IP" 2>/dev/null
    ok "Pivot route removed."
fi
echo

# --- (c) Source-spoofed probe (DMZ -> Internal) ----------------------------
step "Phase C: Forge packets with a DMZ source IP, send to Internal target"
step "This is the most direct test of the firewall's segmentation rule."
step "Expected outcome: firewall DROPS (no response, no SYN-ACK)."
step "If we get a SYN-ACK back, the segmentation rule is missing."

# Use hping3 to craft a SYN with a spoofed DMZ source. The reply (if any)
# will go back to the spoofed source, not us, so we won't see a SYN-ACK
# directly, but the blue team will see in their iptables LOG whether the
# packet was forwarded or dropped.
step "Sending 5 SYNs from spoofed DMZ source $HONEYPOT_IP to $EMPLOYEE_IP:22"
hping3 -S -p 22 -c 5 -a "$HONEYPOT_IP" "$EMPLOYEE_IP" 2>&1 \
    | tee "$OUT/c_spoofed_dmz_to_internal.txt"
echo
step "Sending 5 SYNs from spoofed DMZ source $HONEYPOT_IP to $EMPLOYEE_IP:445"
hping3 -S -p 445 -c 5 -a "$HONEYPOT_IP" "$EMPLOYEE_IP" 2>&1 \
    | tee -a "$OUT/c_spoofed_dmz_to_internal.txt"
echo

ok "Lateral-movement attack complete. Evidence in: $OUT"
echo
echo "For your report, screenshot:"
echo "  - $OUT/a_direct_attacker_to_employee.txt   (baseline reachability)"
echo "  - $OUT/b_via_honeypot_probe.txt            (pivot result)"
echo "  - $OUT/c_spoofed_dmz_to_internal.txt       (source-spoof probe)"
echo "  - The blue team's iptables LOG: should show DMZ->Internal DROPS"
echo "    (sudo journalctl -k | grep 'FW-DROP' | grep '192.168.8')"
echo
warn "KEY POINTS for your report:"
warn "  1. The DMZ exists EXACTLY so an attacker who breaches it cannot"
warn "     immediately reach the protected internal LAN. This is segmentation."
warn "  2. The blue team's firewall must have an explicit rule:"
warn "       iptables -A FORWARD -s $DMZ_SUBNET -d $INTERNAL_SUBNET -j DROP"
warn "  3. If we got responses in phase B/C, the firewall has a gap and the"
warn "     three-subnet design is providing only theatre, not protection."
