# Orion RWA Protocol — Technical Specification & Contract Reference

> This technical reference complements [README.md](file:///d:/Yash/flutter_project/orion/README.md) with detailed contract interface signatures, data structures, state machine diagrams, and RPC interaction standards.

---

## 1. Smart Contract Method Signatures & Interfaces

### 1.1 `IOrionAssetNFT` (Multi-Asset Custodial Token)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOrionAssetNFT {
    enum AssetState {
        PENDING_INTAKE,
        CUSTODY_VERIFIED,
        ACTIVE_TRADING,
        REDEMPTION_LOCKED,
        REDEEMED_BURNED
    }

    struct AssetRecord {
        uint256 assetId;
        string name;
        string symbol;
        bytes32 physicalIdentifierHash; // Hash of IMEI / Serial / VIN / Assay Bar ID
        address custodian;              // Custodian vault address
        uint8 conditionGrade;           // Standardized grade index
        uint256 totalSupply;
        uint256 circulatingSupply;
        AssetState state;
        string ipfsProofUri;            // Custody certificate, insurance policy, photos
    }

    event AssetMinted(uint256 indexed assetId, uint256 initialSupply, address indexed custodian);
    event AssetStateChanged(uint256 indexed assetId, AssetState newState);
    event AssetBurned(uint256 indexed assetId, uint256 amount, uint256 indexed redemptionTicketId);

    function getAsset(uint256 assetId) external view returns (AssetRecord memory);
    function mintAsset(
        address to,
        uint256 assetId,
        uint256 amount,
        bytes32 physicalIdentifierHash,
        address custodian,
        uint8 conditionGrade,
        string calldata ipfsProofUri
    ) external returns (bool);

    function lockForRedemption(address from, uint256 assetId, uint256 amount) external;
    function finalizeBurn(uint256 assetId, uint256 amount, uint256 redemptionTicketId) external;
    function releaseLocked(address to, uint256 assetId, uint256 amount) external;
}
```

---

### 1.2 `IOrionMarketplace` (Primary Sales & Secondary Orders)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOrionMarketplace {
    struct Listing {
        uint256 listingId;
        address seller;
        uint256 assetId;
        uint256 amount;
        uint256 pricePerUnitUSDC; // 6 decimals (standard USDC)
        bool isPrimary;
        bool isActive;
    }

    event ClaimPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 indexed assetId,
        uint256 amount,
        uint256 totalCostUSDC,
        uint256 protocolFeeUSDC
    );

    event ListingCreated(uint256 indexed listingId, address indexed seller, uint256 assetId, uint256 amount, uint256 pricePerUnit);
    event ListingCancelled(uint256 indexed listingId);

    function buyPrimaryClaim(uint256 listingId, uint256 amount) external;
    function buySecondaryClaim(uint256 listingId, uint256 amount) external;
    function listSecondaryClaim(uint256 assetId, uint256 amount, uint256 pricePerUnitUSDC) external returns (uint256 listingId);
    function cancelListing(uint256 listingId) external;
}
```

---

### 1.3 `IOrionRedemptionVault` (Physical Redemption & Courier Settlement)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOrionRedemptionVault {
    enum DeliveryStatus {
        REQUESTED,
        APPROVED_BY_CUSTODIAN,
        DISPATCHED,
        IN_TRANSIT,
        DELIVERED,
        FAILED_RETURNED
    }

    struct RedemptionTicket {
        uint256 ticketId;
        address redeemer;
        uint256 assetId;
        uint256 amount;
        bytes32 shippingDetailsHash; // Encrypted recipient shipping address hash
        bytes32 trackingNumberHash;  // Courier tracking number hash
        DeliveryStatus status;
        uint256 requestedAt;
        uint256 finalizedAt;
    }

    event RedemptionRequested(uint256 indexed ticketId, address indexed redeemer, uint256 assetId, uint256 amount);
    event DispatchInitiated(uint256 indexed ticketId, bytes32 trackingNumberHash);
    event DeliveryConfirmed(uint256 indexed ticketId);
    event RedemptionAborted(uint256 indexed ticketId, string reason);

    function requestRedemption(uint256 assetId, uint256 amount, bytes32 shippingDetailsHash) external returns (uint256 ticketId);
    function markDispatched(uint256 ticketId, bytes32 trackingNumberHash) external;
    function confirmDeliveryAndBurn(uint256 ticketId) external; // Called by Logistics Oracle
    function cancelAndRefund(uint256 ticketId, string calldata reason) external;
}
```

---

### 1.4 `IOrionPriceOracle` (Asset Valuation Feeds)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOrionPriceOracle {
    struct PriceFeedData {
        uint256 priceUSD;      // 8 decimals standard (e.g. 194232000000 = $1,942.32)
        uint256 lastUpdated;
        int256 change24hBasisPoints; // e.g. +132 = +1.32%
        bool isActive;
    }

    function getAssetPrice(uint256 assetId) external view returns (PriceFeedData memory);
    function updateHardwareIndexPrice(uint256 assetId, uint256 newPriceUSD, int256 change24hBps) external;
}
```

---

## 2. Oracle Data Flow & Cryptographic Verification

```
[Off-Chain Vault / Custodian]
       │
       │ (1) Inspection & Assay Certificate
       ▼
[Decentralized IPFS Storage] ──> Content Hash (CID)
       │
       ▼
[OrionSupplierRegistry Contract] ──> On-Chain Attestation
       │
       ▼
[OrionAssetNFT Minting] ──> Liquid Claim Minted
```

### Valuation Oracle Update Mechanism:
1. **Precious Metals**: Automated reading from Chainlink `AggregatorV3Interface` contract addresses (`XAU/USD`, `XAG/USD`).
2. **Electronics & Compute**:
   - Secondary market price index computed from certified API feeds (RunPod, Lambda, StockX, wholesale distributors).
   - Price updates signed with EIP-712 cryptographic signature by authorized oracle relayers.
   - Pushed on-chain when price drift exceeds 1% or every 24 hours.

---

## 3. Production Database Table DDL (PostgreSQL / Neon)

```sql
-- Core Assets Catalog
CREATE TABLE IF NOT EXISTS public.assets (
    id SERIAL PRIMARY KEY,
    token_id BIGINT NOT NULL UNIQUE,
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
    circulating_supply NUMERIC(24, 0) NOT NULL,
    image_url VARCHAR(512),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Portfolio Claims
CREATE TABLE IF NOT EXISTS public.user_claims (
    id SERIAL PRIMARY KEY,
    owner_address VARCHAR(66) NOT NULL,
    asset_id INTEGER REFERENCES public.assets(id),
    amount NUMERIC(24, 0) NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL DEFAULT 'HELD', -- HELD, LISTED, REDEEM_PENDING, REDEEMED
    purchase_price_usd NUMERIC(18, 4) NOT NULL,
    tx_hash VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Time-Series Price Points for Apple-grade Financial Charts
CREATE TABLE IF NOT EXISTS public.asset_price_ticks (
    id BIGSERIAL PRIMARY KEY,
    asset_id INTEGER REFERENCES public.assets(id),
    tick_time TIMESTAMP WITH TIME ZONE NOT NULL,
    price_usd NUMERIC(18, 4) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ticks_asset_time ON public.asset_price_ticks(asset_id, tick_time DESC);

-- Physical Redemption Records
CREATE TABLE IF NOT EXISTS public.redemption_requests (
    ticket_id BIGINT PRIMARY KEY,
    user_claim_id INTEGER REFERENCES public.user_claims(id),
    redeemer_address VARCHAR(66) NOT NULL,
    carrier VARCHAR(64),
    tracking_number VARCHAR(128),
    delivery_status VARCHAR(32) NOT NULL DEFAULT 'REQUESTED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    dispatched_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE
);
```

---

## 4. Flutter Integration Guidelines

When replacing mock repositories:
1. **Authentication**: Use [solana_wallet_service.dart](file:///d:/Yash/flutter_project/orion/lib/features/auth/services/solana_wallet_service.dart) or Web3 provider for session signing.
2. **Asset Listings**: Swap [mock_inventory.dart](file:///d:/Yash/flutter_project/orion/lib/features/marketplace/data/mock_inventory.dart) with `AssetRepository.fetchListings()`, which queries the backend indexer API.
3. **Portfolio**: Swap [portfolio_data.dart](file:///d:/Yash/flutter_project/orion/lib/features/home/models/portfolio_data.dart) with `PortfolioRepository.fetchUserPortfolio()`, aggregating on-chain holdings multiplied by live `OrionPriceOracle` values.
