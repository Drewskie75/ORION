use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum AssetState {
    Draft = 0,
    Active = 1,
    Frozen = 2,
    Closed = 3,
}

#[account]
pub struct AssetAccount {
    /// Unique on-chain numeric asset ID
    pub asset_id: u64,
    /// Associated SPL Token Mint for this RWA claim
    pub mint: Pubkey,
    /// Vault / Custodian public key holding physical asset
    pub custodian: Pubkey,
    /// SHA-256 hash of physical identifier (IMEI, VIN, Bullion Serial, Lot #)
    pub physical_identifier_hash: [u8; 32],
    /// Asset name (e.g., "NVIDIA GPU", "Gold (RWA)", "iPhone 15 Pro")
    pub name: String,
    /// Asset symbol (e.g., "H100", "AU99", "IPH15", "TSLA")
    pub symbol: String,
    /// Category string ("GPU", "Gold", "Phones", "Cars", "RAM")
    pub category: String,
    /// Condition grade: 1=Sealed Grade A, 2=Enterprise New, 3=Fine Bullion
    pub condition_grade: u8,
    /// Total minted supply
    pub total_supply: u64,
    /// Circulating supply
    pub circulating_supply: u64,
    /// Oracle feed account (Pyth or custom feed)
    pub price_oracle_feed: Pubkey,
    /// Base price per unit in USDC (6 decimals, e.g. 742180000 = $742.18)
    pub base_price_usdc: u64,
    /// Current asset status
    pub state: AssetState,
    /// PDA bump
    pub bump: u8,
}

impl AssetAccount {
    pub const MAXIMUM_SIZE: usize = 8 + // discriminator
        8 +  // asset_id
        32 + // mint
        32 + // custodian
        32 + // physical_identifier_hash
        (4 + 32) + // name string
        (4 + 10) + // symbol string
        (4 + 20) + // category string
        1 +  // condition_grade
        8 +  // total_supply
        8 +  // circulating_supply
        32 + // price_oracle_feed
        8 +  // base_price_usdc
        1 +  // state
        1;   // bump
}
