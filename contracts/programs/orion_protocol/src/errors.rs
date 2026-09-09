use anchor_lang::prelude::*;

#[error_code]
pub enum OrionError {
    #[msg("Unauthorized: Caller does not have permission for this action")]
    Unauthorized,

    #[msg("Asset is not currently in an active trading state")]
    AssetNotActive,

    #[msg("Listing is already sold or inactive")]
    ListingInactive,

    #[msg("Insufficient asset quantity available for purchase")]
    InsufficientQuantity,

    #[msg("Price calculation overflow")]
    MathOverflow,

    #[msg("Slippage limit exceeded: price moved beyond acceptable tolerance")]
    PriceSlippageExceeded,

    #[msg("Collateral proposal is not yet approved by certified auditor/custodian")]
    ProposalNotApproved,

    #[msg("Collateral proposal has already been minted")]
    ProposalAlreadyMinted,

    #[msg("Redemption ticket is not in a valid state for this action")]
    InvalidRedemptionState,

    #[msg("Custody serial or identifier hash mismatch")]
    IdentifierHashMismatch,

    #[msg("Stale or invalid price feed from oracle")]
    StaleOraclePrice,

    #[msg("Fee basis points exceed the maximum allowed (1000 = 10%)")]
    FeeTooHigh,

    #[msg("Listing price must be greater than zero")]
    ZeroPrice,

    #[msg("Seller USDC account does not match listing seller")]
    SellerMismatch,

    #[msg("Token mint mismatch: USDC accounts must share the same mint")]
    MintMismatch,

    #[msg("Vault claim account is not owned by the expected escrow PDA")]
    VaultOwnerMismatch,

    #[msg("Redeemer token account mint does not match asset mint")]
    RedeemMintMismatch,

    #[msg("Only the protocol admin can perform this action")]
    AdminOnly,

    #[msg("Only the original supplier can mint from their approved proposal")]
    SupplierMismatch,

    #[msg("Buyer cannot purchase their own listing")]
    SelfPurchase,

    #[msg("Protocol is currently paused")]
    Paused,
}
