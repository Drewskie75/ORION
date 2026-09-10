use anchor_lang::prelude::*;

#[account]
pub struct MarketplaceConfig {
    /// Protocol Super Admin / Multisig
    pub admin: Pubkey,
    /// Protocol Treasury account receiving the 2.5% protocol fee
    pub treasury: Pubkey,
    /// Fee in basis points (250 = 2.50%), hard-capped at 1000 (10%)
    pub fee_bps: u16,
    /// Emergency pause flag — when true, all marketplace operations halt
    pub paused: bool,
    /// Protocol PDA bump
    pub bump: u8,
}

impl MarketplaceConfig {
    // +1 byte for the `paused` bool
    pub const MAXIMUM_SIZE: usize = 8 + 32 + 32 + 2 + 1 + 1;
}

#[account]
pub struct ListingAccount {
    /// Unique listing identifier
    pub listing_id: u64,
    /// Seller address (supplier for primary, user for secondary)
    pub seller: Pubkey,
    /// Referenced AssetAccount PDA
    pub asset_account: Pubkey,
    /// Amount of units available for sale
    pub amount: u64,
    /// Price per unit in USDC (6 decimals)
    pub price_per_unit_usdc: u64,
    /// True if primary sale from supplier, False if secondary P2P trade
    pub is_primary: bool,
    /// Whether the listing is open for purchasing
    pub is_active: bool,
    /// PDA bump
    pub bump: u8,
}

impl ListingAccount {
    pub const MAXIMUM_SIZE: usize = 8 + // discriminator
        8 +  // listing_id
        32 + // seller
        32 + // asset_account
        8 +  // amount
        8 +  // price_per_unit_usdc
        1 +  // is_primary
        1 +  // is_active
        1;   // bump
}
