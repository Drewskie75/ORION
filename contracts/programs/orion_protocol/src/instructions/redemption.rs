use anchor_lang::prelude::*;
use anchor_spl::token::{self, Burn, Token, TokenAccount, Transfer};
use crate::state::asset::{AssetAccount, AssetState};
use crate::state::marketplace::MarketplaceConfig;
use crate::state::redemption::{RedemptionStatus, RedemptionTicket};
use crate::errors::OrionError;

/// Seeds for the escrow vault PDA that holds locked claim tokens during redemption.
pub const ESCROW_SEED: &[u8] = b"escrow_vault";

#[derive(Accounts)]
#[instruction(ticket_id: u64)]
pub struct RequestRedemption<'info> {
    #[account(
        init,
        payer = redeemer,
        space = RedemptionTicket::MAXIMUM_SIZE,
        seeds = [b"redemption", ticket_id.to_le_bytes().as_ref()],
        bump
    )]
    pub ticket: Account<'info, RedemptionTicket>,

    #[account(
        mut,
        constraint = asset.state == AssetState::Active @ OrionError::AssetNotActive
    )]
    pub asset: Account<'info, AssetAccount>,

    /// Protocol config must not be paused
    #[account(
        seeds = [b"marketplace_config"],
        bump = config.bump,
        constraint = !config.paused @ OrionError::Paused
    )]
    pub config: Account<'info, MarketplaceConfig>,

    /// Redeemer's claim token account (from which tokens are escrowed into vault).
    /// SEC-FIX: Validate the redeemer actually owns this token account
    /// and the mint matches the asset mint.
    #[account(
        mut,
        constraint = redeemer_claim_account.owner == redeemer.key() @ OrionError::Unauthorized,
        constraint = redeemer_claim_account.mint == asset.mint @ OrionError::RedeemMintMismatch
    )]
    pub redeemer_claim_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Escrow vault claim account owned by the ticket PDA
    #[account(
        init,
        payer = redeemer,
        token::mint = asset_mint,
        token::authority = ticket
    )]
    pub vault_claim_account: Account<'info, TokenAccount>,

    /// CHECK: The mint of the asset claim tokens
    #[account(address = asset.mint)]
    pub asset_mint: AccountInfo<'info>,

    #[account(mut)]
    pub redeemer: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

pub fn request(
    ctx: Context<RequestRedemption>,
    ticket_id: u64,
    amount: u64,
    shipping_details_hash: [u8; 32],
) -> Result<()> {
    require!(amount > 0, OrionError::InsufficientQuantity);

    // 1. Escrow claim tokens into the protocol vault PDA
    let transfer_ctx = Transfer {
        from: ctx.accounts.redeemer_claim_account.to_account_info(),
        to: ctx.accounts.vault_claim_account.to_account_info(),
        authority: ctx.accounts.redeemer.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), transfer_ctx),
        amount,
    )?;

    // 2. Initialize the Redemption Ticket
    let ticket = &mut ctx.accounts.ticket;
    ticket.ticket_id = ticket_id;
    ticket.redeemer = ctx.accounts.redeemer.key();
    ticket.asset_account = ctx.accounts.asset.key();
    ticket.amount = amount;
    ticket.shipping_details_hash = shipping_details_hash;
    ticket.tracking_hash = [0u8; 32];
    ticket.status = RedemptionStatus::Requested;
    ticket.requested_at = Clock::get()?.unix_timestamp;
    ticket.finalized_at = 0;
    ticket.bump = ctx.bumps.ticket;

    msg!("Redemption #{} requested for {} units of asset {}", ticket_id, amount, ctx.accounts.asset.asset_id);
    Ok(())
}

#[derive(Accounts)]
pub struct MarkDispatched<'info> {
    #[account(
        mut,
        constraint = ticket.status == RedemptionStatus::Requested @ OrionError::InvalidRedemptionState
    )]
    pub ticket: Account<'info, RedemptionTicket>,

    #[account(
        address = ticket.asset_account,
        has_one = custodian @ OrionError::Unauthorized
    )]
    pub asset: Account<'info, AssetAccount>,

    /// Only the registered custodian can mark as dispatched
    pub custodian: Signer<'info>,
}

pub fn dispatch(ctx: Context<MarkDispatched>, tracking_hash: [u8; 32]) -> Result<()> {
    let ticket = &mut ctx.accounts.ticket;
    ticket.tracking_hash = tracking_hash;
    ticket.status = RedemptionStatus::Dispatched;
    msg!("Redemption #{} marked as dispatched by custodian", ticket.ticket_id);
    Ok(())
}

#[derive(Accounts)]
pub struct ConfirmDeliveryAndBurn<'info> {
    #[account(
        mut,
        constraint = ticket.status == RedemptionStatus::Dispatched @ OrionError::InvalidRedemptionState
    )]
    pub ticket: Account<'info, RedemptionTicket>,

    #[account(
        mut,
        address = ticket.asset_account
    )]
    pub asset: Account<'info, AssetAccount>,

    /// CHECK: SPL Token mint to burn tokens from.
    /// SEC-FIX: Validated that mint matches asset.mint to prevent burning wrong tokens.
    #[account(mut, address = asset.mint)]
    pub mint: AccountInfo<'info>,

    /// Escrow vault account holding the locked tokens.
    /// SEC-FIX: Validate mint, owner (ticket PDA), and ensure it has enough tokens.
    #[account(
        mut,
        constraint = vault_claim_account.owner == ticket.key() @ OrionError::VaultOwnerMismatch,
        constraint = vault_claim_account.mint == asset.mint @ OrionError::RedeemMintMismatch,
        constraint = vault_claim_account.amount >= ticket.amount @ OrionError::InsufficientQuantity
    )]
    pub vault_claim_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Restricted to only the asset custodian.
    /// Previously ANY signer could call this and burn tokens + mark as delivered,
    /// which would let an attacker burn escrowed tokens without actual physical delivery.
    #[account(
        constraint = authority.key() == asset.custodian @ OrionError::Unauthorized
    )]
    pub authority: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

pub fn confirm_and_burn(ctx: Context<ConfirmDeliveryAndBurn>) -> Result<()> {
    let ticket = &mut ctx.accounts.ticket;
    let asset = &mut ctx.accounts.asset;

    // 1. Burn the escrowed claim tokens permanently
    let ticket_id_bytes = ticket.ticket_id.to_le_bytes();
    let bump_array = [ticket.bump];
    let signer_seeds: &[&[&[u8]]] = &[&[
        b"redemption",
        ticket_id_bytes.as_ref(),
        &bump_array,
    ]];

    let burn_ctx = Burn {
        mint: ctx.accounts.mint.to_account_info(),
        from: ctx.accounts.vault_claim_account.to_account_info(),
        authority: ticket.to_account_info(),
    };
    token::burn(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            burn_ctx,
            signer_seeds,
        ),
        ticket.amount,
    )?;

    // 2. Decrement circulating supply
    asset.circulating_supply = asset
        .circulating_supply
        .checked_sub(ticket.amount)
        .ok_or(OrionError::MathOverflow)?;

    // 3. Mark ticket Delivered
    ticket.status = RedemptionStatus::Delivered;
    ticket.finalized_at = Clock::get()?.unix_timestamp;

    msg!(
        "Redemption #{} delivered and {} units permanently burned. Remaining supply: {}",
        ticket.ticket_id, ticket.amount, asset.circulating_supply
    );
    Ok(())
}
