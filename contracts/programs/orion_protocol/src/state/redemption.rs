use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum RedemptionStatus {
    Requested = 0,
    Dispatched = 1,
    Delivered = 2,
    Cancelled = 3,
}

#[account]
pub struct RedemptionTicket {
    /// Unique redemption ticket ID
    pub ticket_id: u64,
    /// Wallet address requesting physical delivery
    pub redeemer: Pubkey,
    /// Target AssetAccount
    pub asset_account: Pubkey,
    /// Number of claims being redeemed
    pub amount: u64,
    /// Encrypted SHA-256 hash of recipient name and shipping address
    pub shipping_details_hash: [u8; 32],
    /// Courier tracking number hash (FedEx, DHL, Brink's)
    pub tracking_hash: [u8; 32],
    /// Current redemption lifecycle status
    pub status: RedemptionStatus,
    /// Unix timestamp when redemption was initiated
    pub requested_at: i64,
    /// Unix timestamp when delivered/burned
    pub finalized_at: i64,
    /// PDA bump
    pub bump: u8,
}

impl RedemptionTicket {
    pub const MAXIMUM_SIZE: usize = 8 + // discriminator
        8 +  // ticket_id
        32 + // redeemer
        32 + // asset_account
        8 +  // amount
        32 + // shipping_details_hash
        32 + // tracking_hash
        1 +  // status
        8 +  // requested_at
        8 +  // finalized_at
        1;   // bump
}
