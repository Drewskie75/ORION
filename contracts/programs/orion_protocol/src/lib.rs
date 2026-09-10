use anchor_lang::prelude::*;

pub mod errors;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS");

#[program]
pub mod orion_protocol {
    use super::*;

    /// 1. Initialize Protocol & Treasury Configuration
    pub fn initialize_protocol(ctx: Context<InitializeProtocol>, fee_bps: u16) -> Result<()> {
        instructions::initialize::handler(ctx, fee_bps)
    }

    /// 2. Admin: Update protocol fee (capped at 10%)
    pub fn update_fee(ctx: Context<UpdateFee>, new_fee_bps: u16) -> Result<()> {
        instructions::initialize::update_fee(ctx, new_fee_bps)
    }

    /// 3. Admin: Emergency pause / unpause all marketplace operations
    pub fn set_paused(ctx: Context<SetPaused>, paused: bool) -> Result<()> {
        instructions::initialize::set_paused(ctx, paused)
    }

    /// 4. Collateral Intake: Supplier proposes new inventory batch
    pub fn propose_collateral(
        ctx: Context<ProposeCollateral>,
        proposal_id: u64,
        asset_id: u64,
        category: String,
        condition_grade: u8,
        physical_identifier_hash: [u8; 32],
        proposed_units: u64,
    ) -> Result<()> {
        instructions::intake::propose(
            ctx,
            proposal_id,
            asset_id,
            category,
            condition_grade,
            physical_identifier_hash,
            proposed_units,
        )
    }

    /// 5. Collateral Intake: Custodian audits and approves proposal
    pub fn approve_collateral(ctx: Context<ApproveCollateral>) -> Result<()> {
        instructions::intake::approve(ctx)
    }

    /// 6. Tokenization: Mint RWA Claim Token account (supplier-only)
    pub fn mint_rwa_claim(
        ctx: Context<MintRwaClaim>,
        asset_id: u64,
        name: String,
        symbol: String,
        base_price_usdc: u64,
    ) -> Result<()> {
        instructions::mint_claim::handler(ctx, asset_id, name, symbol, base_price_usdc)
    }

    /// 7. Marketplace: List claims for sale (primary or secondary)
    pub fn list_asset(
        ctx: Context<ListAsset>,
        listing_id: u64,
        amount: u64,
        price_per_unit_usdc: u64,
        is_primary: bool,
    ) -> Result<()> {
        instructions::trade::list(ctx, listing_id, amount, price_per_unit_usdc, is_primary)
    }

    /// 8. Marketplace: Purchase claim with USDC (routes fee to Treasury)
    pub fn buy_claim(ctx: Context<BuyClaim>, units_to_buy: u64) -> Result<()> {
        instructions::trade::buy(ctx, units_to_buy)
    }

    /// 9. Physical Redemption: Lock claim into vault and request delivery
    pub fn request_redemption(
        ctx: Context<RequestRedemption>,
        ticket_id: u64,
        amount: u64,
        shipping_details_hash: [u8; 32],
    ) -> Result<()> {
        instructions::redemption::request(ctx, ticket_id, amount, shipping_details_hash)
    }

    /// 10. Physical Redemption: Custodian marks item as dispatched with tracking
    pub fn mark_dispatched(ctx: Context<MarkDispatched>, tracking_hash: [u8; 32]) -> Result<()> {
        instructions::redemption::dispatch(ctx, tracking_hash)
    }

    /// 11. Physical Redemption: Custodian confirms delivery & burns token
    pub fn confirm_delivery_and_burn(ctx: Context<ConfirmDeliveryAndBurn>) -> Result<()> {
        instructions::redemption::confirm_and_burn(ctx)
    }
}
