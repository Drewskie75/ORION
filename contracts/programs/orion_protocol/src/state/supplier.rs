use anchor_lang::prelude::*;

#[account]
pub struct SupplierProposal {
    /// Unique proposal ID
    pub proposal_id: u64,
    /// Supplier submitting the inventory intake
    pub supplier: Pubkey,
    /// Targeted asset ID
    pub asset_id: u64,
    /// Category ("GPU", "Phones", "Gold", "Cars", "RAM")
    pub category: String,
    /// Condition grade: 1=Sealed Grade A, 2=Enterprise New, 3=Fine Bullion
    pub condition_grade: u8,
    /// SHA-256 hash of serials/lots
    pub physical_identifier_hash: [u8; 32],
    /// Proposed unit quantity
    pub proposed_units: u64,
    /// Assigned certified custodian / auditor
    pub auditor: Pubkey,
    /// Approved by auditor after physical vault inspection
    pub is_approved: bool,
    /// Minted into liquid tokens
    pub is_minted: bool,
    /// PDA bump
    pub bump: u8,
}

impl SupplierProposal {
    pub const MAXIMUM_SIZE: usize = 8 + // discriminator
        8 +  // proposal_id
        32 + // supplier
        8 +  // asset_id
        (4 + 20) + // category
        1 +  // condition_grade
        32 + // physical_identifier_hash
        8 +  // proposed_units
        32 + // auditor
        1 +  // is_approved
        1 +  // is_minted
        1;   // bump
}
