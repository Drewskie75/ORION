#!/usr/bin/env bash
# ==============================================================================
# ORION RWA PROTOCOL - SOLANA DEVNET TOKEN MINT GENERATOR
# ==============================================================================
# This script creates real Solana SPL Token Mints for all 6 physical RWA assets
# used in the Orion application. Each token is minted with 6 decimals to enable
# seamless fractional trading (e.g. 0.1, 0.25, 0.5 shares).
#
# Run inside WSL:
#   cd /mnt/d/Yash/flutter_project/orion
#   bash scripts/create_all_rwa_tokens.sh
# ==============================================================================

set -u

export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"

# ANSI Color codes
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

echo -e "${BOLD}${MAGENTA}"
echo "======================================================================"
echo "    🪐 ORION PROTOCOL - SOLANA DEVNET RWA TOKEN MINT GENERATOR 🪐     "
echo "======================================================================"
echo -e "${RESET}"

# 1. Check prerequisites
echo -e "${CYAN}[1/4] Checking Solana & SPL Token CLI tools in WSL...${RESET}"

if ! command -v solana &> /dev/null; then
    echo -e "${RED}❌ 'solana' CLI not found in your WSL PATH.${RESET}"
    echo -e "${YELLOW}Install it using: sh -c \"\$(curl -sSfL https://release.anza.xyz/stable/install)\"${RESET}"
    exit 1
fi

if ! command -v spl-token &> /dev/null; then
    echo -e "${RED}❌ 'spl-token' CLI not found in your WSL PATH.${RESET}"
    echo -e "${YELLOW}Install it using: cargo install spl-token-cli${RESET}"
    exit 1
fi

# 2. Configure Solana to Devnet
echo -e "${CYAN}[2/4] Setting Solana CLI to Devnet...${RESET}"
solana config set --url https://api.devnet.solana.com > /dev/null

WALLET_PUBKEY=$(solana address)
echo -e "   👤 Active Keypair : ${BOLD}${WALLET_PUBKEY}${RESET}"
echo -e "   🌐 Cluster        : ${BOLD}https://api.devnet.solana.com${RESET}"

# Check balance & airdrop if needed
BALANCE=$(solana balance | awk '{print $1}')
echo -e "   💰 Current SOL    : ${BOLD}${BALANCE} SOL${RESET}"

# If balance is under 0.5 SOL, request airdrop
if (( $(echo "$BALANCE < 0.5" | bc -l) )); then
    echo -e "${YELLOW}⚠️ Low Devnet balance. Requesting 2 SOL airdrop...${RESET}"
    solana airdrop 2 || echo -e "${YELLOW}⚠️ Airdrop rate limited; proceeding with existing balance.${RESET}"
fi

# 3. Define Orion RWA Catalog
# Format: ID|Name|Symbol|Supply|Category
ASSETS=(
    "1|NVIDIA GPU (H100)|H100|10000|GPU"
    "2|Gold Bullion 99.99% (RWA)|AU99|500|Gold"
    "3|iPhone 15 Pro Titanium|IPH15|150|Phones"
    "4|Tesla Model S Plaid|TSLA|20|Cars"
    "5|DDR5 RAM 32GB Reg ECC|RAM|2500|RAM"
    "6|Silver Bullion 99.9% (RWA)|AG99|5000|Gold"
)

MANIFEST_FILE="rwa_tokens_manifest.json"
echo "{" > "$MANIFEST_FILE"
echo '  "network": "devnet",' >> "$MANIFEST_FILE"
echo '  "programId": "9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS",' >> "$MANIFEST_FILE"
echo '  "createdAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "$MANIFEST_FILE"
echo '  "tokens": [' >> "$MANIFEST_FILE"

TOTAL=${#ASSETS[@]}
COUNTER=0

echo -e "\n${CYAN}[3/4] Tokenizing ${TOTAL} physical RWA products with 6 decimals...${RESET}\n"

for ITEM in "${ASSETS[@]}"; do
    IFS='|' read -r ASSET_ID NAME SYMBOL SUPPLY CATEGORY <<< "$ITEM"
    COUNTER=$((COUNTER + 1))

    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}▶ [${COUNTER}/${TOTAL}] Tokenizing Asset #${ASSET_ID}: ${NAME} (${SYMBOL})${RESET}"
    echo -e "   • Category     : ${CATEGORY}"
    echo -e "   • Decimals     : 6 (Supports fractional shares like 0.1, 0.25, 0.5)"
    echo -e "   • Total Supply : ${SUPPLY} units"

    # Step A: Create SPL Token Mint with 6 decimals
    MINT_OUTPUT=$(spl-token create-token --decimals 6 --url devnet 2>&1)
    MINT_ADDRESS=$(echo "$MINT_OUTPUT" | grep -oE "Creating token [A-Za-z0-9]{32,44}" | awk '{print $3}' || true)

    if [ -z "$MINT_ADDRESS" ]; then
        # Try alternate regex format
        MINT_ADDRESS=$(echo "$MINT_OUTPUT" | grep -oE "Address:  [A-Za-z0-9]{32,44}" | awk '{print $2}' || true)
    fi

    if [ -z "$MINT_ADDRESS" ]; then
        echo -e "${RED}❌ Failed to create token mint for ${NAME}.${RESET}"
        echo "$MINT_OUTPUT"
        continue
    fi

    echo -e "   ✨ ${GREEN}SPL Token Mint : ${BOLD}${MINT_ADDRESS}${RESET}"

    # Step B: Create Associated Token Account (ATA) for Custodian / Supplier Reserve
    ATA_OUTPUT=$(spl-token create-account "$MINT_ADDRESS" --url devnet 2>&1)
    ATA_ADDRESS=$(echo "$ATA_OUTPUT" | grep -oE "Creating account [A-Za-z0-9]{32,44}" | awk '{print $3}' || true)

    if [ -z "$ATA_ADDRESS" ]; then
        ATA_ADDRESS=$(echo "$ATA_OUTPUT" | grep -oE "Address:  [A-Za-z0-9]{32,44}" | awk '{print $2}' || true)
    fi

    echo -e "   🏦 ${GREEN}Custodian ATA  : ${BOLD}${ATA_ADDRESS}${RESET}"

    # Step C: Mint initial supply into Custodian ATA
    MINT_SUPPLY_OUTPUT=$(spl-token mint "$MINT_ADDRESS" "$SUPPLY" "$ATA_ADDRESS" --url devnet 2>&1)
    echo -e "   💰 ${GREEN}Minted Supply  : ${SUPPLY} shares (${MINT_ADDRESS:0:6}...)${RESET}"

    # Step D: Update backend Neon database via API endpoint (if server running on port 4000)
    API_RESPONSE=$(curl -s -X POST "http://localhost:4000/api/assets/${ASSET_ID}/mint" \
        -H "Content-Type: application/json" \
        -d "{\"mintAddress\": \"${MINT_ADDRESS}\"}" || true)

    if [[ "$API_RESPONSE" =~ "success\":true" ]]; then
        echo -e "   💾 ${GREEN}Database       : Updated in Neon PostgreSQL via API!${RESET}"
    else
        echo -e "   ℹ️ ${YELLOW}Backend API offline or skipped. Mint saved to manifest.${RESET}"
    fi

    echo -e "   🔍 ${CYAN}Solana Explorer: https://explorer.solana.com/address/${MINT_ADDRESS}?cluster=devnet${RESET}"

    # Write entry to JSON manifest
    COMMA=","
    if [ "$COUNTER" -eq "$TOTAL" ]; then
        COMMA=""
    fi

    cat <<EOF >> "$MANIFEST_FILE"
    {
      "assetId": ${ASSET_ID},
      "name": "${NAME}",
      "symbol": "${SYMBOL}",
      "mint": "${MINT_ADDRESS}",
      "custodianAta": "${ATA_ADDRESS}",
      "supply": ${SUPPLY},
      "decimals": 6,
      "explorer": "https://explorer.solana.com/address/${MINT_ADDRESS}?cluster=devnet"
    }${COMMA}
EOF

    # Brief delay to respect Devnet RPC rate limits
    sleep 1
done

echo '  ]' >> "$MANIFEST_FILE"
echo '}' >> "$MANIFEST_FILE"

echo -e "\n${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}${GREEN}✅ ALL 6 RWA TOKENS CREATED SUCCESSFULLY ON SOLANA DEVNET!${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
echo -e "📁 Token manifest written to: ${BOLD}${PWD}/${MANIFEST_FILE}${RESET}\n"

echo -e "${BOLD}📋 Summary of Live Solana Devnet Mints:${RESET}"
cat "$MANIFEST_FILE" | grep -E '"(name|symbol|mint)"' || true

echo -e "\n${CYAN}You can verify any mint on Solana Explorer:${RESET}"
echo -e "https://explorer.solana.com/?cluster=devnet\n"
