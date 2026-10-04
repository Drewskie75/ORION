# Orion Solana Anchor Contracts — WSL Deployment Guide

> **Security-hardened Solana Anchor smart contracts** for the Orion RWA Protocol.

---

## Security Audit Changelog

The following critical and high-severity vulnerabilities were identified and **fixed**:

### 🔴 CRITICAL: Fund Drain via Seller Account Substitution (`trade.rs`)

**Before**: `BuyClaim` accepted *any* `seller_usdc_account` without verifying it belonged to `listing.seller`. An attacker could:
1. Find any active listing
2. Pass their own USDC account as `seller_usdc_account`
3. Buy 0 or 1 unit, and ALL the seller's proceeds would route to the attacker's account

**Fix**: Added constraint `seller_usdc_account.owner == listing.seller` so proceeds can only flow to the actual seller.

---

### 🔴 CRITICAL: Unauthorized Token Burn via Open `confirm_delivery_and_burn` (`redemption.rs`)

**Before**: `ConfirmDeliveryAndBurn` accepted *any signer* as `authority`. An attacker could:
1. Find any `Dispatched` redemption ticket
2. Call `confirm_delivery_and_burn` themselves, burning the escrowed tokens
3. The physical asset never ships, but the digital claim is destroyed — permanent loss for the redeemer

**Fix**: Added constraint `authority.key() == asset.custodian` so only the registered vault custodian can confirm delivery and trigger token burn.

---

### 🔴 CRITICAL: Proposal Hijack — Anyone Can Mint From Approved Proposals (`mint_claim.rs`)

**Before**: `MintRwaClaim` had no check that the caller was the original supplier. Any wallet could call `mint_rwa_claim` with a valid approved `proposal` PDA and mint tokens for themselves.

**Fix**: Added constraint `authority.key() == proposal.supplier` so only the supplier who submitted the proposal can mint from it.

---

### 🟠 HIGH: No Fee Cap — Admin Can Set 100% Fee (`initialize.rs`)

**Before**: `initialize_protocol` accepted any `fee_bps` value including `10000` (100%). A compromised or malicious admin could set the fee to 100%, causing every buyer's entire payment to go to the treasury — sellers receive nothing.

**Fix**: Hard-capped `fee_bps` at `MAX_FEE_BPS = 1000` (10%). Both `initialize_protocol` and the new `update_fee` instruction enforce this cap.

---

### 🟠 HIGH: No Emergency Pause Mechanism

**Before**: If a vulnerability was discovered in production, there was no way to halt operations. Exploiters could drain funds while the team scrambles.

**Fix**: Added `paused` boolean flag to `MarketplaceConfig` and a new admin-only `set_paused` instruction. All instructions (`list_asset`, `buy_claim`, `request_redemption`, `mint_rwa_claim`) now check `!config.paused`.

---

### 🟠 HIGH: Zero-Price Listings Allow Free Asset Acquisition (`trade.rs`)

**Before**: `list_asset` did not validate `price_per_unit_usdc > 0`. An attacker could create a listing with price `0`, and any buyer could acquire assets for free.

**Fix**: Added `require!(price_per_unit_usdc > 0, OrionError::ZeroPrice)`.

---

### 🟡 MEDIUM: USDC Mint Mismatch — Cross-Token Drain (`trade.rs`)

**Before**: No validation that `buyer_usdc_account`, `seller_usdc_account`, and `treasury_usdc_account` all share the same SPL token mint. An attacker could pass worthless custom token accounts as "USDC" while receiving real assets.

**Fix**: Added `constraint = X.mint == buyer_usdc_account.mint` on both seller and treasury accounts.

---

### 🟡 MEDIUM: Self-Purchase for Fake Volume (`trade.rs`)

**Before**: A seller could buy their own listing to artificially inflate trading volume and mislead other users.

**Fix**: Added `require!(buyer.key() != listing.seller, OrionError::SelfPurchase)`.

---

### 🟡 MEDIUM: Redemption Token Account Validation (`redemption.rs`)

**Before**: `redeemer_claim_account` had no ownership or mint check. An attacker could pass any token account, potentially escrowing tokens they don't own or tokens of the wrong type.

**Fix**: Added constraints: `redeemer_claim_account.owner == redeemer.key()` and `redeemer_claim_account.mint == asset.mint`.

---

### 🟡 MEDIUM: String Overflow in Account Space (`mint_claim.rs`)

**Before**: `name` and `symbol` strings had no length validation. If a name longer than 32 bytes was passed, the account would fail to serialize (or worse, overflow into adjacent fields).

**Fix**: Added `require!(name.len() <= 32)` and `require!(symbol.len() <= 10)`.

---

### 🟢 LOW: Vault Balance Pre-Check (`redemption.rs`)

**Before**: `vault_claim_account.amount >= ticket.amount` was never checked before burning. The burn CPI would fail anyway, but a clear error message helps debugging.

**Fix**: Added explicit balance check with `OrionError::InsufficientQuantity`.

---

## Program Instructions (11 total)

| # | Instruction | Access Control |
|---|---|---|
| 1 | `initialize_protocol` | Admin (first-time only, PDA init) |
| 2 | `update_fee` | Admin only (`has_one = admin`) |
| 3 | `set_paused` | Admin only (`has_one = admin`) |
| 4 | `propose_collateral` | Any supplier (pays rent) |
| 5 | `approve_collateral` | Assigned auditor only (`has_one = auditor`) |
| 6 | `mint_rwa_claim` | Original supplier only (not paused) |
| 7 | `list_asset` | Any seller (not paused) |
| 8 | `buy_claim` | Any buyer ≠ seller (not paused) |
| 9 | `request_redemption` | Claim token holder (not paused) |
| 10 | `mark_dispatched` | Asset custodian only |
| 11 | `confirm_delivery_and_burn` | Asset custodian only |

---

## Prerequisites (Inside WSL Ubuntu)

```bash
# 1. Update packages
sudo apt update && sudo apt install -y pkg-config build-essential libudev-dev libssl-dev clang

# 2. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 3. Install Solana CLI (v1.18.x)
sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# 4. Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install 0.30.1
avm use 0.30.1

# 5. Verify
solana --version
anchor --version
```

## Configure Wallet

```bash
solana-keygen new --outfile ~/.config/solana/id.json
solana config set --url https://api.devnet.solana.com
solana airdrop 2
```

## Build, Test & Deploy

```bash
cd /mnt/d/Yash/flutter_project/orion/contracts

yarn install
anchor build

# Get your program ID and update Anchor.toml + lib.rs
solana address -k target/deploy/orion_protocol-keypair.json
anchor build  # Rebuild after ID update

# Test
anchor test

# Deploy to Devnet
anchor deploy --provider.cluster devnet

# Seed initial assets
yarn seed
```
