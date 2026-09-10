use anchor_lang::prelude::*;
use crate::state::supplier::SupplierProposal;
use crate::errors::OrionError;

#[derive(Accounts)]
#[instruction(proposal_id: u64)]
pub struct ProposeCollateral<'info> {
    #[account(
        init,
        payer = supplier,
        space = SupplierProposal::MAXIMUM_SIZE,
        seeds = [b"proposal", proposal_id.to_le_bytes().as_ref()],
        bump
    )]
    pub proposal: Account<'info, SupplierProposal>,

    /// CHECK: The assigned certified custodian / auditor
    pub auditor: AccountInfo<'info>,

    #[account(mut)]
    pub supplier: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn propose(
    ctx: Context<ProposeCollateral>,
    proposal_id: u64,
    asset_id: u64,
    category: String,
    condition_grade: u8,
    physical_identifier_hash: [u8; 32],
    proposed_units: u64,
) -> Result<()> {
    let proposal = &mut ctx.accounts.proposal;
    proposal.proposal_id = proposal_id;
    proposal.supplier = ctx.accounts.supplier.key();
    proposal.asset_id = asset_id;
    proposal.category = category;
    proposal.condition_grade = condition_grade;
    proposal.physical_identifier_hash = physical_identifier_hash;
    proposal.proposed_units = proposed_units;
    proposal.auditor = ctx.accounts.auditor.key();
    proposal.is_approved = false;
    proposal.is_minted = false;
    proposal.bump = ctx.bumps.proposal;

    msg!("Supplier proposal #{} submitted for asset {}", proposal_id, asset_id);
    Ok(())
}

#[derive(Accounts)]
pub struct ApproveCollateral<'info> {
    #[account(
        mut,
        has_one = auditor @ OrionError::Unauthorized,
        constraint = !proposal.is_approved @ OrionError::Unauthorized
    )]
    pub proposal: Account<'info, SupplierProposal>,

    pub auditor: Signer<'info>,
}

pub fn approve(ctx: Context<ApproveCollateral>) -> Result<()> {
    let proposal = &mut ctx.accounts.proposal;
    proposal.is_approved = true;
    msg!("Supplier proposal #{} approved by certified auditor", proposal.proposal_id);
    Ok(())
}
