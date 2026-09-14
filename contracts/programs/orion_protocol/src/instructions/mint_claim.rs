use anchor_lang::prelude::*;
use crate::state::asset::{AssetAccount, AssetState};
use crate::state::supplier::SupplierProposal;
use crate::state::marketplace::MarketplaceConfig;
use crate::errors::OrionError;

#[derive(Accounts)]
#[instruction(asset_id: u64)]
pub struct MintRwaClaim<'info> {
    #[account(
        init,
        payer = authority,
        space = AssetAccount::MAXIMUM_SIZE,
        seeds = [b"asset", asset_id.to_le_bytes().as_ref()],
        bump
    )]
    pub asset: Account<'info, AssetAccount>,

    #[account(
        mut,
        constraint = proposal.is_approved @ OrionError::ProposalNotApproved,
        constraint = !proposal.is_minted @ OrionError::ProposalAlreadyMinted,
        constraint = proposal.asset_id == asset_id @ OrionError::IdentifierHashMismatch,
    )]
    pub proposal: Account<'info, SupplierProposal>,

    /// SEC-FIX: Only the original supplier who submitted the proposal can mint.
    /// This prevents an attacker from hijacking an approved proposal.
    #[account(
        constraint = authority.key() == proposal.supplier @ OrionError::SupplierMismatch
    )]
    pub authority: Signer<'info>,

    /// Protocol config must not be paused
    #[account(
        seeds = [b"marketplace_config"],
        bump = config.bump,
        constraint = !config.paused @ OrionError::Paused
    )]
    pub config: Account<'info, MarketplaceConfig>,

    /// CHECK: SPL Token mint representing the digital claim.
    /// In production, this instruction should CPI into spl_token::initialize_mint
    /// to guarantee the mint is freshly created and controlled by the program PDA.
    pub mint: AccountInfo<'info>,

    /// CHECK: Custodian vault holding physical item
    pub custodian: AccountInfo<'info>,

    /// CHECK: Oracle feed (Pyth or custom price feed)
    pub price_oracle_feed: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<MintRwaClaim>,
    asset_id: u64,
    name: String,
    symbol: String,
    base_price_usdc: u64,
) -> Result<()> {
    // SEC-FIX: Validate string lengths to prevent account space overflow
    require!(name.len() <= 32, OrionError::MathOverflow);
    require!(symbol.len() <= 10, OrionError::MathOverflow);

    let proposal = &mut ctx.accounts.proposal;
    let asset = &mut ctx.accounts.asset;

    asset.asset_id = asset_id;
    asset.mint = ctx.accounts.mint.key();
    asset.custodian = ctx.accounts.custodian.key();
    asset.physical_identifier_hash = proposal.physical_identifier_hash;
    asset.name = name;
    asset.symbol = symbol;
    asset.category = proposal.category.clone();
    asset.condition_grade = proposal.condition_grade;
    asset.total_supply = proposal.proposed_units;
    asset.circulating_supply = proposal.proposed_units;
    asset.price_oracle_feed = ctx.accounts.price_oracle_feed.key();
    asset.base_price_usdc = base_price_usdc;
    asset.state = AssetState::Active;
    asset.bump = ctx.bumps.asset;

    proposal.is_minted = true;

    msg!(
        "RWA Asset #{} ('{}') successfully tokenized with {} units",
        asset_id, asset.name, asset.total_supply
    );
    Ok(())
}
