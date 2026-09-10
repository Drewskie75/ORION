use anchor_lang::prelude::*;
use crate::state::marketplace::MarketplaceConfig;
use crate::errors::OrionError;

/// Maximum allowable fee: 10% (1000 basis points)
pub const MAX_FEE_BPS: u16 = 1000;

#[derive(Accounts)]
pub struct InitializeProtocol<'info> {
    #[account(
        init,
        payer = admin,
        space = MarketplaceConfig::MAXIMUM_SIZE,
        seeds = [b"marketplace_config"],
        bump
    )]
    pub config: Account<'info, MarketplaceConfig>,

    /// CHECK: Treasury account receiving protocol fees
    pub treasury: AccountInfo<'info>,

    #[account(mut)]
    pub admin: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeProtocol>, fee_bps: u16) -> Result<()> {
    // SEC-FIX: Cap fee to prevent admin from setting a 100% fee that drains buyers
    require!(fee_bps <= MAX_FEE_BPS, OrionError::FeeTooHigh);

    let config = &mut ctx.accounts.config;
    config.admin = ctx.accounts.admin.key();
    config.treasury = ctx.accounts.treasury.key();
    config.fee_bps = fee_bps;
    config.paused = false;
    config.bump = ctx.bumps.config;
    msg!("Orion Protocol initialized. Fee: {} bps, Treasury: {}", fee_bps, config.treasury);
    Ok(())
}

/// Admin-only instruction to update the protocol fee
#[derive(Accounts)]
pub struct UpdateFee<'info> {
    #[account(
        mut,
        seeds = [b"marketplace_config"],
        bump = config.bump,
        has_one = admin @ OrionError::AdminOnly
    )]
    pub config: Account<'info, MarketplaceConfig>,

    pub admin: Signer<'info>,
}

pub fn update_fee(ctx: Context<UpdateFee>, new_fee_bps: u16) -> Result<()> {
    require!(new_fee_bps <= MAX_FEE_BPS, OrionError::FeeTooHigh);
    ctx.accounts.config.fee_bps = new_fee_bps;
    msg!("Protocol fee updated to {} bps", new_fee_bps);
    Ok(())
}

/// Admin-only emergency pause/unpause
#[derive(Accounts)]
pub struct SetPaused<'info> {
    #[account(
        mut,
        seeds = [b"marketplace_config"],
        bump = config.bump,
        has_one = admin @ OrionError::AdminOnly
    )]
    pub config: Account<'info, MarketplaceConfig>,

    pub admin: Signer<'info>,
}

pub fn set_paused(ctx: Context<SetPaused>, paused: bool) -> Result<()> {
    ctx.accounts.config.paused = paused;
    msg!("Protocol paused = {}", paused);
    Ok(())
}
