#!/bin/bash
# run_all.sh - Master demo runner. Walks through all five attacks
# with prompts between each so you can narrate during the recording.

source "$(dirname "$0")/config.sh"
require_root

cd "$(dirname "$0")" || exit 1

pause() {
    echo
    echo -e "${CYA}>>> Press ENTER to continue to the next attack <<<${NC}"
    read -r
    clear
}

clear
banner "CS 445 RED TEAM DEMO -- ALL ATTACKS"
echo
echo "This script will run the full threat-model demo in order:"
echo "  1. Reconnaissance (nmap)"
echo "  2. DoS flood (hping3)"
echo "  3. ARP spoof / MitM (arpspoof) WARNING - requires secondary VM"
echo "  4. SSH brute force (hydra)"
echo "  5. Lateral movement DMZ -> Internal"
echo
echo "Evidence will be collected in: $EVIDENCE_DIR"
echo
echo -e "${YEL}Tip: have your screen recorder running BEFORE you press ENTER.${NC}"
pause

bash attack1_recon.sh
pause

bash attack2_dos.sh
pause

echo -e "${YEL}Attack 3 (ARP spoof) requires a secondary VM in 10.10.10.0/24.${NC}"
echo "Skip? [y/N]"
read -r SKIP3
if [[ ! "$SKIP3" =~ ^[Yy]$ ]]; then
    bash attack3_arpspoof.sh
    pause
fi

bash attack4_brute.sh
pause

bash attack5_lateral.sh

echo
banner "DEMO COMPLETE"
echo "All evidence saved under: $EVIDENCE_DIR"
ls -la "$EVIDENCE_DIR" | tail -n +2
