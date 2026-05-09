# CS 445 —Attacker Scripts

Threat-model deliverables for the CS 445 final project. Five attacks plus a master runner, designed for the team's three-subnet network with a Cowrie honeypot in a dedicated DMZ.

---

##Target Architecture

```
                    External (10.10.10.0/24)
                    [Attacker — Kali]
                    10.10.10.100
                          │
                          │
                    [Router/FW/IDS — Debian]
                    iptables + Snort
                  ┌───────┼───────┐
                  │               │
       DMZ                Internal
       (192.168.8.0/24)   (192.168.4.0/24)
       [Honeypot]         [Employee PC]
       192.168.8.100      192.168.4.100
```

The employee PC is the real target. The honeypot is a tripwire in an isolated DMZ — any traffic to it is, by definition, unauthorised. The DMZ is also the testbed for **network segmentation** (the firewall must block DMZ-to-Internal traffic, which Attack 5 verifies).

---

## File layout

| File | Purpose |
|------|---------|
| `config.sh` | Shared variables (target IPs, interface name, evidence dir). **Edit this if anything doesnt match VM IPs.** |
| `attack1_recon.sh` | nmap host discovery across DMZ + Internal, scans of both targets, ending with a stealth scan that evades IDS thresholds |
| `attack2_dos.sh` | hping3 SYN/ICMP/UDP floods against the employee PC + availability measurements |
| `attack3_arpspoof.sh` | Layer-2 ARP cache poisoning within the External subnet (the "firewall can't see this" demo) |
| `attack4_brute.sh` | Three-phase SSH brute force: naive → honeypot → aggressive employee → slow rate-limit-evading employee |
| `attack5_lateral.sh` | Verifies the firewall blocks honeypot-to-employee pivot. |
| `run_all.sh` | Walks through all five attacks with pauses for narration |

---

## One-time setup on the Kali attacker VM

```bash
sudo apt update
sudo apt install -y nmap hping3 hydra dsniff tshark tcpdump curl

chmod +x *.sh
```

---

## Cowrie honeypot setup (for the blue team)

On a fresh Debian/Ubuntu VM with IP `192.168.8.100` in the DMZ:

```bash
# Dependencies
sudo apt update
sudo apt install -y python3-venv python3-dev libssl-dev libffi-dev \
                    build-essential authbind git

# Cowrie user + clone
sudo adduser --disabled-password --gecos "" cowrie
sudo -u cowrie -i
git clone https://github.com/cowrie/cowrie.git
cd cowrie
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Config: copy default
cp etc/cowrie.cfg.dist etc/cowrie.cfg
# Then edit etc/cowrie.cfg:
#   listen_endpoints = tcp:22:interface=0.0.0.0

# Move the real SSH off port 22 BEFORE starting Cowrie!
# Edit /etc/ssh/sshd_config:  Port 2222
# sudo systemctl restart ssh

# Start Cowrie
bin/cowrie start

# Logs to watch during the demo:
tail -f var/log/cowrie/cowrie.log       # human-readable
tail -f var/log/cowrie/cowrie.json      # structured JSON
```

 **Move real SSH off port 22 first** (e.g. to 2222) so Cowrie can take over port 22 — otherwise you'll lock yourself out of the honeypot VM.

The default Cowrie config will accept the password `123456` for user `root`. Any login attempt is logged with timestamp, source IP, username, password, and (if the attacker proceeds) every shell command they type.

---

## Required firewall rule for Attack 5

For your blue team's iptables ruleset to pass Attack 5, it MUST contain an explicit deny on DMZ-to-Internal traffic:

```bash
# Block all forwarding from DMZ into the internal LAN
iptables -A FORWARD -s 192.168.8.0/24 -d 192.168.4.0/24 \
         -j LOG --log-prefix "DMZ-TO-INT-DROP: "
iptables -A FORWARD -s 192.168.8.0/24 -d 192.168.4.0/24 -j DROP
```

This is the single most important rule that justifies having a DMZ in the first place. Without it, the three-subnet design provides only theatre.

---

## How to run during the demo

### Recommended sequence

1. **Baseline pass.** Blue team flushes their firewall and stops Snort. Run `sudo ./run_all.sh`. Shows what an undefended network looks like — every attack succeeds.
2. **Defended pass.** Blue team re-applies firewall rules and starts Snort. Run `sudo ./run_all.sh` again. Most attacks blocked or detected.
3. **The advanced-attacker moment.** Point out:
   - Phase D of attack 1 (stealth scan) still completes against the employee PC.
   - Attack 3 (ARP spoof) was never visible to the firewall at all.
   - Phase C of attack 4 (slow brute force) makes progress under the rate limit.
   - **The honeypot caught the naive attempts immediately** — phase A of attack 4 lit up Cowrie before the blue team even checked Snort.
   - Attack 5 confirms the DMZ-to-Internal segmentation works (or surfaces a gap if it doesn't).

### Running individual attacks

```bash
sudo ./attack1_recon.sh        # ~5 min total (phase D is slow)
sudo ./attack2_dos.sh          # ~45 sec
sudo ./attack3_arpspoof.sh     # ~1 min (requires interaction)
sudo ./attack4_brute.sh        # ~5 min (phase C has 20s sleeps)
sudo ./attack5_lateral.sh      # ~30 sec
```

---

## Evidence collection

Every script writes a timestamped folder under `~/redteam_evidence/`. For the report, screenshot:

| Source | What to capture |
|--------|-----------------|
| Attacker terminal | Each script's output during attacks |
| Cowrie logs | `var/log/cowrie/cowrie.json` showing the captured login attempts (and shell session if attacker proceeded) |
| Snort alert file | `/var/log/snort/alert` entries that correspond in time to each attack |
| iptables LOG | `sudo journalctl -k \| grep -E 'FW-DROP\|SSH-BRUTE\|DMZ-TO-INT-DROP'` |
| Wireshark | Open `attack3_arpspoof_*/02_intercepted_traffic.pcap` and screenshot the cleartext HTTP |

---

## Mapping each attack to the threat-model rubric

| Attack | Section in report | Rubric criterion it satisfies |
|--------|-------------------|-------------------------------|
| 1. Recon (phases A–C) | §2.2 Attack 1 | Multiple attack types; evidence (scan output) |
| 1. Recon phase D | §2.2 Attack 1 (advanced) | **Advanced attacker** — evades IDS threshold |
| 2. DoS flood | §2.2 Attack 2 | Multiple attack types; tests firewall rate limits |
| 3. ARP spoof | §2.2 Attack 3 | **Advanced attacker** — bypasses perimeter entirely |
| 4. Brute force phase A | §2.2 Attack 4 | **Honeypot tripwire** — first detection signal |
| 4. Brute force phase C | §2.2 Attack 4 (advanced) | **Advanced attacker** — evades rate limit |
| 5. Lateral movement | §2.2 Attack 5 | **Network segmentation test** — justifies DMZ design |

---

## IMPORTANT Safety reminders

These scripts perform real network attacks:

- Only run them against the lab targets defined in `config.sh`.
- Do not run them on shared university networks or any network you do not own.
- The DoS script will saturate the victim's interface — make sure your group is okay with that during the demo window.
- Attack 5 includes source-IP spoofing (hping3 `-a`) — fine inside the lab, illegal on the Internet.
