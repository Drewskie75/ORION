-- ==============================================================================
-- Orion RWA Protocol: Neon PostgreSQL Production Schema
-- ==============================================================================

-- 1. Asset Catalog (Reflects On-Chain AssetAccount records)
CREATE TABLE IF NOT EXISTS assets (
    id SERIAL PRIMARY KEY,
    asset_id BIGINT NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(32) NOT NULL,
    category VARCHAR(64) NOT NULL,
    grade VARCHAR(128) NOT NULL,
    specification TEXT NOT NULL,
    identifier VARCHAR(128) NOT NULL,
    custodian_id VARCHAR(128) NOT NULL,
    vault_location VARCHAR(255) NOT NULL,
    price_usd NUMERIC(18, 4) NOT NULL,
    change_24h_pct NUMERIC(6, 2) DEFAULT 0.00,
    total_supply NUMERIC(24, 0) NOT NULL,
    available_supply NUMERIC(24, 0) NOT NULL,
    liquidity_usd NUMERIC(18, 2) DEFAULT 0.00,
    volume_24h_usd NUMERIC(18, 2) DEFAULT 0.00,
    image_asset VARCHAR(512),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. User Owned Claims (Reflects wallet token balances and custody state)
CREATE TABLE IF NOT EXISTS user_claims (
    id SERIAL PRIMARY KEY,
    owner_address VARCHAR(66) NOT NULL,
    asset_id BIGINT REFERENCES assets(asset_id),
    amount NUMERIC(24, 0) NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL DEFAULT 'Held', -- 'Held', 'Listed', 'Redemption_Requested', 'Redeemed'
    acquired_price_usd NUMERIC(18, 4) NOT NULL,
    tx_hash VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- SEC-FIX: Prevent the indexer from double-crediting assets on websocket reconnects
    UNIQUE(tx_hash, asset_id, owner_address)
);
CREATE INDEX IF NOT EXISTS idx_user_claims_owner ON user_claims(owner_address);

-- 3. Price History Ticks (Feeds 1D, 1W, 1M, 1Y, ALL interactive Apple charts)
CREATE TABLE IF NOT EXISTS asset_price_ticks (
    id BIGSERIAL PRIMARY KEY,
    asset_id BIGINT REFERENCES assets(asset_id),
    tick_time TIMESTAMP WITH TIME ZONE NOT NULL,
    price_usd NUMERIC(18, 4) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ticks_asset_time ON asset_price_ticks(asset_id, tick_time DESC);

-- 4. Physical Redemption Tickets
CREATE TABLE IF NOT EXISTS redemption_tickets (
    ticket_id BIGINT PRIMARY KEY,
    claim_id INTEGER REFERENCES user_claims(id),
    redeemer_address VARCHAR(66) NOT NULL,
    carrier VARCHAR(64),
    tracking_number VARCHAR(128),
    delivery_status VARCHAR(32) NOT NULL DEFAULT 'Requested', -- 'Requested', 'Dispatched', 'Delivered', 'Cancelled'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    dispatched_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE
);

-- 5. Supplier Collateral Intake Proposals
CREATE TABLE IF NOT EXISTS supplier_proposals (
    proposal_id BIGINT PRIMARY KEY,
    supplier_address VARCHAR(66) NOT NULL,
    asset_id BIGINT NOT NULL,
    category VARCHAR(64) NOT NULL,
    condition_grade VARCHAR(64) NOT NULL,
    proposed_units NUMERIC(24, 0) NOT NULL,
    auditor_address VARCHAR(66) NOT NULL,
    is_approved BOOLEAN DEFAULT FALSE,
    is_minted BOOLEAN DEFAULT FALSE,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
