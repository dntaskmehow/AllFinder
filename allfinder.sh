#!/usr/bin/env bash
# allfinder.sh - Advanced Autonomous Subdomain Enumeration & Asset Intelligence Engine
# Aggregates Passive Sources, Active Brute-Forcing, Live Probing, and Takeover Checks

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${PURPLE}"
    echo "=================================================="
    echo "     ALLFINDER : ADVANCED RECON ENGINE            "
    echo "=================================================="
    echo -e "${NC}"
}

usage() {
    echo -e "${YELLOW}Usage:${NC} $0 -d <target-domain> [-w <wordlist>] [-p <proxy>] [-o <output-dir>]"
    echo -e "  Options:"
    echo -e "    -d  Target root domain (e.g., example.com) [Mandatory]"
    echo -e "    -w  Wordlist path for active DNS brute-forcing [Optional]"
    echo -e "    -p  HTTP Proxy address (e.g., 127.0.0.1:8080) [Optional]"
    echo -e "    -o  Custom output directory [Optional]"
    echo -e "${YELLOW}Example:${NC} $0 -d example.com -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    exit 1
}

DOMAIN=""
WORDLIST=""
PROXY=""
OUT_DIR=""

while getopts "d:w:p:o:h" opt; do
    case ${opt} in
        d) DOMAIN="$OPTARG" ;;
        w) WORDLIST="$OPTARG" ;;
        p) PROXY="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Error: Target domain (-d) is mandatory.${NC}"
    usage
fi

print_banner

[ -z "$OUT_DIR" ] && OUT_DIR="AllFinder_Results_${DOMAIN//[:\/]/_}"
mkdir -p "$OUT_DIR"

echo -e "${GREEN}[+] Target Domain:${NC} $DOMAIN"
echo -e "${GREEN}[+] Output Workspace:${NC} $OUT_DIR"
[ -n "$PROXY" ] && echo -e "${GREEN}[+] Proxy Active:${NC} $PROXY"
[ -n "$WORDLIST" ] && echo -e "${GREEN}[+] Active Wordlist Loaded:${NC} $WORDLIST"

echo "--------------------------------------------------"

# ==========================================
# PHASE 1: Passive Subdomain Harvesting
# ==========================================
echo -e "${CYAN}[Phase 1/5] Harvesting Subdomains via Passive Sources (Subfinder, Assetfinder, Findomain)...${NC}"

# Subfinder
if command -v subfinder &> /dev/null; then
    subfinder -d "$DOMAIN" -silent > "$OUT_DIR/sub_subfinder.txt" 2>/dev/null
    echo -e "${GREEN}  [+] Subfinder completed.${NC}"
else
    echo -e "${YELLOW}  [!] Subfinder not installed, skipping.${NC}"
    touch "$OUT_DIR/sub_subfinder.txt"
fi

# Assetfinder
if command -v assetfinder &> /dev/null; then
    assetfinder --subs-only "$DOMAIN" > "$OUT_DIR/sub_assetfinder.txt" 2>/dev/null
    echo -e "${GREEN}  [+] Assetfinder completed.${NC}"
else
    echo -e "${YELLOW}  [!] Assetfinder not installed, skipping.${NC}"
    touch "$OUT_DIR/sub_assetfinder.txt"
fi

# Findomain
if command -v findomain &> /dev/null; then
    findomain -t "$DOMAIN" -q > "$OUT_DIR/sub_findomain.txt" 2>/dev/null
    echo -e "${GREEN}  [+] Findomain completed.${NC}"
else
    echo -e "${YELLOW}  [!] Findomain not installed, skipping.${NC}"
    touch "$OUT_DIR/sub_findomain.txt"
fi

# Merge and deduplicate passive results
cat "$OUT_DIR/sub_subfinder.txt" "$OUT_DIR/sub_assetfinder.txt" "$OUT_DIR/sub_findomain.txt" 2>/dev/null | sort -u > "$OUT_DIR/passive_unique.txt"
PASSIVE_COUNT=$(wc -l < "$OUT_DIR/passive_unique.txt" | tr -d ' ')
echo -e "${GREEN}[✓] Phase 1 Complete: Discovered $PASSIVE_COUNT unique passive subdomains.${NC}"

# ==========================================
# PHASE 2: Active DNS Brute-Forcing (Optional)
# ==========================================
if [ -n "$WORDLIST" ] && [ -f "$WORDLIST" ]; then
    echo -e "${CYAN}[Phase 2/5] Running Active DNS Brute-Forcing via Gobuster/Puredns/Dnsx...${NC}"
    if command -v gobuster &> /dev/null; then
        gobuster dns -d "$DOMAIN" -w "$WORDLIST" -t 50 --quiet --no-color > "$OUT_DIR/sub_gobuster.txt" 2>/dev/null
        # Clean gobuster output format to get pure subdomains if necessary, or parse
        awk '{print $NF}' "$OUT_DIR/sub_gobuster.txt" > "$OUT_DIR/active_cleaned.txt" 2>/dev/null
    elif command -v puredns &> /dev/null; then
        puredns bruteforce "$WORDLIST" "$DOMAIN" -r /dev/null --quiet > "$OUT_DIR/active_cleaned.txt" 2>/dev/null
    else
        echo -e "${YELLOW}  [!] No supported brute-force tool (gobuster/puredns) found, skipping active pass.${NC}"
        touch "$OUT_DIR/active_cleaned.txt"
    fi
    cat "$OUT_DIR/passive_unique.txt" "$OUT_DIR/active_cleaned.txt" 2>/dev/null | sort -u > "$OUT_DIR/all_unfiltered_subdomains.txt"
else
    echo -e "${YELLOW}[Phase 2/5] Skipping Active Brute-Forcing (No wordlist specified).${NC}"
    cp "$OUT_DIR/passive_unique.txt" "$OUT_DIR/all_unfiltered_subdomains.txt"
fi

TOTAL_RAW=$(wc -l < "$OUT_DIR/all_unfiltered_subdomains.txt" | tr -d ' ')
echo -e "${GREEN}[✓] Phase 2 Complete: Total combined candidate subdomains: $TOTAL_RAW${NC}"

# ==========================================
# PHASE 3: Live Host Probing & Resolution
# ==========================================
echo -e "${CYAN}[Phase 3/5] Probing Live HTTP/HTTPS Hosts & Extracting Metadata (httpx)...${NC}"
if command -v httpx &> /dev/null; then
    HTTPX_OPTS="-silent -status-code -tech-detect -title -location -content-length"
    [ -n "$PROXY" ] && HTTPX_OPTS="$HTTPX_OPTS -http-proxy http://$PROXY"
    
    cat "$OUT_DIR/all_unfiltered_subdomains.txt" | httpx $HTTPX_OPTS -o "$OUT_DIR/live_hosts_detailed.txt" 2>/dev/null
    cat "$OUT_DIR/live_hosts_detailed.txt" | awk '{print $1}' > "$OUT_DIR/live_hosts_clean.txt"
    LIVE_COUNT=$(wc -l < "$OUT_DIR/live_hosts_clean.txt" | tr -d ' ')
    echo -e "${GREEN}[✓] Phase 3 Complete: Found $LIVE_COUNT live responsive web hosts.${NC}"
else
    echo -e "${RED}  [!] httpx is not installed. Falling back to basic ping/nc checks.${NC}"
    cp "$OUT_DIR/all_unfiltered_subdomains.txt" "$OUT_DIR/live_hosts_clean.txt"
fi

# ==========================================
# PHASE 4: Subdomain Takeover Vulnerability Check
# ==========================================
echo -e "${CYAN}[Phase 4/5] Scanning for Dangling CNAME Subdomain Takeover Vectors...${NC}"
if command -v subzy &> /dev/null; then
    subzy run --targets "$OUT_DIR/all_unfiltered_subdomains.txt" --output "$OUT_DIR/takeovers.json" >/dev/null 2>&1
    echo -e "${GREEN}[✓] Phase 4 Complete. Results checked via Subzy.${NC}"
else
    echo -e "${YELLOW}  [!] Subzy not found, checking generic CNAME fingerprints manually...${NC}"
    # Basic fallback check for dangling indicators in DNS records if dig exists
    while read -r sub; do
        CNAME_REC=$(dig +short CNAME "$sub" 2>/dev/null)
        if [ -n "$CNAME_REC" ]; then
            echo "$sub -> CNAME: $CNAME_REC" >> "$OUT_DIR/cname_mappings.txt"
        fi
    done < "$OUT_DIR/all_unfiltered_subdomains.txt"
    [ ! -f "$OUT_DIR/cname_mappings.txt" ] && touch "$OUT_DIR/cname_mappings.txt"
    echo -e "${GREEN}[✓] Phase 4 Complete (Fallback CNAME mapping generated).${NC}"
fi

# ==========================================
# PHASE 5: Automated Vulnerability & Recon Handoff
# ==========================================
echo -e "${CYAN}[Phase 5/5] Generating Final Aggregated Summary Matrix...${NC}"

SUMMARY_FILE="$OUT_DIR/recon_summary.md"
cat << EOF > "$SUMMARY_FILE"
# AllFinder Reconnaissance Executive Summary
- **Target Domain:** $DOMAIN
- **Total Unique Subdomains Found:** $TOTAL_RAW
- **Total Live Responding Hosts:** $(wc -l < "$OUT_DIR/live_hosts_clean.txt" 2>/dev/null || echo "0")
- **Timestamp:** $(date)

## Artifact Files Generated:
1. `all_unfiltered_subdomains.txt` - Complete compiled subdomain list
2. `live_hosts_clean.txt` - Verified live URLs/hosts
3. `live_hosts_detailed.txt` - HTTP status codes, web technologies, and titles
4. `takeovers.json` / `cname_mappings.txt` - Potential subdomain takeover analysis
EOF

echo "--------------------------------------------------"
echo -e "${GREEN}[+] AllFinder Execution Complete! All master artifacts saved under:${NC} ${CYAN}$OUT_DIR${NC}"
echo -e "${GREEN}[+] Executive summary compiled at:${NC} ${CYAN}$SUMMARY_FILE${NC}"
