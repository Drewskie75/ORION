import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { expect } from "chai";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, createMint, getOrCreateAssociatedTokenAccount, mintTo } from "@solana/spl-token";

describe("orion_protocol", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // @ts-ignore
  const program = anchor.workspace.OrionProtocol as Program<any>;

  const admin = provider.wallet;
  const treasury = Keypair.generate();
  const supplier = Keypair.generate();
  const auditor = Keypair.generate();
  const buyer = Keypair.generate();

  let usdcMint: PublicKey;
  let buyerUsdcAccount: any;
  let supplierUsdcAccount: any;
  let treasuryUsdcAccount: any;

  before(async () => {
    // Airdrop SOL to test actors
    const tx1 = await provider.connection.requestAirdrop(supplier.publicKey, 2 * anchor.web3.LAMPORTS_PER_SOL);
    await provider.connection.confirmTransaction(tx1);

    const tx2 = await provider.connection.requestAirdrop(buyer.publicKey, 2 * anchor.web3.LAMPORTS_PER_SOL);
    await provider.connection.confirmTransaction(tx2);

    const tx3 = await provider.connection.requestAirdrop(auditor.publicKey, 2 * anchor.web3.LAMPORTS_PER_SOL);
    await provider.connection.confirmTransaction(tx3);
  });

  it("1. Initializes the protocol configuration with 2.5% fee (250 bps)", async () => {
    const [configPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("marketplace_config")],
      program.programId
    );

    await program.methods
      .initializeProtocol(250) // 250 bps = 2.5%
      .accounts({
        config: configPda,
        treasury: treasury.publicKey,
        admin: admin.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    const configAccount = await program.account.marketplaceConfig.fetch(configPda);
    expect(configAccount.feeBps).to.equal(250);
    expect(configAccount.admin.toBase58()).to.equal(admin.publicKey.toBase58());
    expect(configAccount.treasury.toBase58()).to.equal(treasury.publicKey.toBase58());
  });

  it("2. Submits a supplier intake proposal for NVIDIA H100 cluster", async () => {
    const proposalId = new anchor.BN(101);
    const [proposalPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("proposal"), proposalId.toArrayLike(Buffer, "le", 8)],
      program.programId
    );

    const dummyHash = new Array(32).fill(7);

    await program.methods
      .proposeCollateral(
        proposalId,
        new anchor.BN(1), // asset_id: 1 (NVIDIA H100)
        "GPU",
        2, // Enterprise New
        dummyHash,
        new anchor.BN(10000) // 10,000 cluster shares
      )
      .accounts({
        proposal: proposalPda,
        auditor: auditor.publicKey,
        supplier: supplier.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([supplier])
      .rpc();

    const proposalAccount = await program.account.supplierProposal.fetch(proposalPda);
    expect(proposalAccount.isApproved).to.be.false;
    expect(proposalAccount.category).to.equal("GPU");
  });

  it("3. Custodian / Auditor inspects vault and approves proposal", async () => {
    const proposalId = new anchor.BN(101);
    const [proposalPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("proposal"), proposalId.toArrayLike(Buffer, "le", 8)],
      program.programId
    );

    await program.methods
      .approveCollateral()
      .accounts({
        proposal: proposalPda,
        auditor: auditor.publicKey,
      })
      .signers([auditor])
      .rpc();

    const proposalAccount = await program.account.supplierProposal.fetch(proposalPda);
    expect(proposalAccount.isApproved).to.be.true;
  });
});
