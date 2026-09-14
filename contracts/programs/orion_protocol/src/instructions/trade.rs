use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};
use crate::state::asset::{AssetAccount, AssetState};
use crate::state::marketplace::{ListingAccount, MarketplaceConfig};
use crate::errors::OrionError;

#[derive(Accounts)]
#[instruction(listing_id: u64)]
pub struct ListAsset<'info> {
    #[account(
        init,
        payer = seller,
        space = ListingAccount::MAXIMUM_SIZE,
        seeds = [b"listing", listing_id.to_le_bytes().as_ref()],
        bump
    )]
    pub listing: Account<'info, ListingAccount>,

    #[account(
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

    #[account(mut)]
    pub seller: Signer<'info>,

    /// SEC-FIX: Seller's claim token account (from which tokens are escrowed)
    #[account(
        mut,
        constraint = seller_claim_account.owner == seller.key() @ OrionError::Unauthorized,
        constraint = seller_claim_account.mint == asset.mint @ OrionError::MintMismatch
    )]
    pub seller_claim_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Escrow token account owned by the listing PDA
    #[account(
        init,
        payer = seller,
        token::mint = asset_mint,
        token::authority = listing
    )]
    pub escrow_claim_account: Account<'info, TokenAccount>,

    /// CHECK: The mint of the asset claim tokens
    #[account(address = asset.mint)]
    pub asset_mint: AccountInfo<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

pub fn list(
    ctx: Context<ListAsset>,
    listing_id: u64,
    amount: u64,
    price_per_unit_usdc: u64,
    is_primary: bool,
) -> Result<()> {
    require!(amount > 0, OrionError::InsufficientQuantity);
    // SEC-FIX: Zero-price listings would let anyone acquire assets for free
    require!(price_per_unit_usdc > 0, OrionError::ZeroPrice);

    let listing = &mut ctx.accounts.listing;
    listing.listing_id = listing_id;
    listing.seller = ctx.accounts.seller.key();
    listing.asset_account = ctx.accounts.asset.key();
    listing.amount = amount;
    listing.price_per_unit_usdc = price_per_unit_usdc;
    listing.is_primary = is_primary;
    listing.is_active = true;
    listing.bump = ctx.bumps.listing;

    // SEC-FIX: Actually escrow the claim tokens from seller to the listing PDA
    let transfer_ctx = Transfer {
        from: ctx.accounts.seller_claim_account.to_account_info(),
        to: ctx.accounts.escrow_claim_account.to_account_info(),
        authority: ctx.accounts.seller.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), transfer_ctx),
        amount,
    )?;

    msg!("Asset listed: #{} for {} units at {} USDC/unit", listing_id, amount, price_per_unit_usdc);
    Ok(())
}

#[derive(Accounts)]
pub struct BuyClaim<'info> {
    #[account(
        seeds = [b"marketplace_config"],
        bump = config.bump,
        // SEC-FIX: Enforce pause check on every purchase
        constraint = !config.paused @ OrionError::Paused
    )]
    pub config: Account<'info, MarketplaceConfig>,

    #[account(
        mut,
        constraint = listing.is_active @ OrionError::ListingInactive
    )]
    pub listing: Account<'info, ListingAccount>,

    #[account(
        mut,
        address = listing.asset_account,
        constraint = asset.state == AssetState::Active @ OrionError::AssetNotActive
    )]
    pub asset: Account<'info, AssetAccount>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    /// Buyer's USDC token account
    #[account(
        mut,
        constraint = buyer_usdc_account.owner == buyer.key() @ OrionError::Unauthorized,
        constraint = buyer_usdc_account.mint == seller_usdc_account.mint @ OrionError::MintMismatch
    )]
    pub buyer_usdc_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Seller's USDC account MUST belong to the listing seller.
    /// Without this, an attacker can pass their own account as "seller_usdc_account"
    /// and redirect all sale proceeds to themselves.
    #[account(
        mut,
        constraint = seller_usdc_account.owner == listing.seller @ OrionError::SellerMismatch,
        constraint = seller_usdc_account.mint == buyer_usdc_account.mint @ OrionError::MintMismatch
    )]
    pub seller_usdc_account: Account<'info, TokenAccount>,

    /// Treasury's USDC token account receiving protocol fee (2.5%).
    /// Validated against the config treasury AND same mint as buyer.
    #[account(
        mut,
        constraint = treasury_usdc_account.owner == config.treasury @ OrionError::Unauthorized,
        constraint = treasury_usdc_account.mint == buyer_usdc_account.mint @ OrionError::MintMismatch
    )]
    pub treasury_usdc_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Escrow token account owned by the listing PDA (holds the claim tokens)
    #[account(
        mut,
        constraint = escrow_claim_account.owner == listing.key() @ OrionError::Unauthorized,
        constraint = escrow_claim_account.mint == asset.mint @ OrionError::MintMismatch
    )]
    pub escrow_claim_account: Account<'info, TokenAccount>,

    /// SEC-FIX: Buyer's claim token account (receives the claim tokens)
    #[account(
        mut,
        constraint = buyer_claim_account.owner == buyer.key() @ OrionError::Unauthorized,
        constraint = buyer_claim_account.mint == asset.mint @ OrionError::MintMismatch
    )]
    pub buyer_claim_account: Account<'info, TokenAccount>,

    /// Token program for SPL transfers
    pub token_program: Program<'info, Token>,
}

pub fn buy(ctx: Context<BuyClaim>, units_to_buy: u64) -> Result<()> {
    let listing = &mut ctx.accounts.listing;
    require!(units_to_buy > 0 && units_to_buy <= listing.amount, OrionError::InsufficientQuantity);

    // SEC-FIX: Prevent self-purchase (seller buying their own listing to fake volume)
    require!(ctx.accounts.buyer.key() != listing.seller, OrionError::SelfPurchase);

    // Compute gross cost: units * price_per_unit
    let gross_cost: u64 = units_to_buy
        .checked_mul(listing.price_per_unit_usdc)
        .ok_or(OrionError::MathOverflow)?;

    // Compute protocol fee (e.g., 250 bps = 2.5%)
    let protocol_fee: u64 = gross_cost
        .checked_mul(ctx.accounts.config.fee_bps as u64)
        .ok_or(OrionError::MathOverflow)?
        .checked_div(10000)
        .ok_or(OrionError::MathOverflow)?;

    let net_to_seller = gross_cost
        .checked_sub(protocol_fee)
        .ok_or(OrionError::MathOverflow)?;

    // 1. Transfer net proceeds to seller
    let transfer_to_seller = Transfer {
        from: ctx.accounts.buyer_usdc_account.to_account_info(),
        to: ctx.accounts.seller_usdc_account.to_account_info(),
        authority: ctx.accounts.buyer.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), transfer_to_seller),
        net_to_seller,
    )?;

    // 2. Transfer protocol fee to Treasury
    if protocol_fee > 0 {
        let transfer_to_treasury = Transfer {
            from: ctx.accounts.buyer_usdc_account.to_account_info(),
            to: ctx.accounts.treasury_usdc_account.to_account_info(),
            authority: ctx.accounts.buyer.to_account_info(),
        };
        token::transfer(
            CpiContext::new(ctx.accounts.token_program.to_account_info(), transfer_to_treasury),
            protocol_fee,
        )?;
    }

    // 3. Update listing state
    listing.amount = listing.amount.checked_sub(units_to_buy).ok_or(OrionError::MathOverflow)?;
    if listing.amount == 0 {
        listing.is_active = false;
    }

    // 4. SEC-FIX: Transfer claim tokens from listing escrow to buyer
    let listing_id_bytes = listing.listing_id.to_le_bytes();
    let bump_array = [listing.bump];
    let signer_seeds: &[&[&[u8]]] = &[&[
        b"listing",
        listing_id_bytes.as_ref(),
        &bump_array,
    ]];

    let transfer_claim = Transfer {
        from: ctx.accounts.escrow_claim_account.to_account_info(),
        to: ctx.accounts.buyer_claim_account.to_account_info(),
        authority: listing.to_account_info(),
    };
    token::transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            transfer_claim,
            signer_seeds,
        ),
        units_to_buy,
    )?;

    msg!(
        "Purchased {} units of listing #{} (Asset #{}). Gross: {} USDC, Fee: {} USDC, Net to seller: {} USDC",
        units_to_buy, listing.listing_id, asset.asset_id, gross_cost, protocol_fee, net_to_seller
    );

    Ok(())
}
