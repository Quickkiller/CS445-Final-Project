#!/bin/bash
# Shared configuration for all red-team attack scripts.
# Source this file from each attack script: source ./config.sh

# --- Network targets ---------------------------------------------------------
# Architecture:
#   External subnet : 10.10.10.0/24    (attacker @ 10.10.10.100)
#   Internal subnet : 192.168.4.0/24   (employee @ 192.168.4.100)
#   DMZ subnet      : 192.168.8.0/24   (honeypot @ 192.168.8.100)
# Adjust these if any of these IPs change (IMPORTANT).

ATTACKER_IP="10.10.10.100"        # This machine
EMPLOYEE_IP="192.168.4.100"       # The REAL target (employee workstation)
HONEYPOT_IP="192.168.8.100"       # The TRIPWIRE (Cowrie honeypot in DMZ)
VICTIM_IP="$EMPLOYEE_IP"          # Default victim used by attacks 2, 4
INTERNAL_SUBNET="192.168.4.0/24"  # Blue-team internal subnet
DMZ_SUBNET="192.168.8.0/24"       # DMZ subnet
EXTERNAL_SUBNET="10.10.10.0/24"   # Attacker's subnet
GATEWAY_IP="10.10.10.1"           # The custom router (attacker-side interface)
ATTACKER_IFACE="eth0"             # Attacker's primary NIC

# --- For ARP spoof demo (within attacker's own subnet) -----------------------
SECONDARY_VICTIM_IP="10.10.10.50" # A second host in 10.10.10.0/24 to MITM

# --- Evidence capture --------------------------------------------------------
EVIDENCE_DIR="$HOME/redteam_evidence"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$EVIDENCE_DIR"

# --- Coloured output for the demo --------------------------------------------
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYA='\033[0;36m'
NC='\033[0m'   # no colour

banner() {
    echo -e "${CYA}============================================================${NC}"
    echo -e "${CYA} $1${NC}"
    echo -e "${CYA}============================================================${NC}"
}

step() {
    echo -e "${YEL}[*] $1${NC}"
}

ok() {
    echo -e "${GRN}[+] $1${NC}"
}

warn() {
    echo -e "${RED}[!] $1${NC}"
}

# Require root for raw-socket attacks
require_root() {
    if [ "$EUID" -ne 0 ]; then
        warn "This script needs root. Re-run with: sudo $0"
        exit 1
    fi
}
