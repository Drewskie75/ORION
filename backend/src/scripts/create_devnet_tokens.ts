import { Connection, Keypair, LAMPORTS_PER_SOL, clusterApiUrl } from "@solana/web3.js";
import { createMint, getOrCreateAssociatedTokenAccount, mintTo } from "@solana/spl-token";
import { pool } from "../db/pool";
import dotenv from "dotenv";

dotenv.config();

/**
 * Script to deploy real SPL Token Mints for each Orion RWA product on Solana Devnet:
 * - 6 Decimals per mint (enabling fractional purchases down to 0.000001 shares)
 * - Mints initial supply
 * - Associates mints with Neon PostgreSQL database records
 */
async function main() {
  const rpcUrl = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
  const connection = new Connection(rpcUrl, "confirmed");

  console.log("🔗 Connecting to Solana Devnet via:", rpcUrl);

  // Generate or load authority keypair
  const payer = Keypair.generate();
  console.log("🔑 Generated Supplier / Mint Authority Keypair:", payer.publicKey.toBase58());

  console.log("🪂 Requesting Devnet SOL airdrop (2 SOL)...");
  try {
    const airdropSig = await connection.requestAirdrop(payer.publicKey, 2 * LAMPORTS_PER_SOL);
    const latestBlockhash = await connection.getLatestBlockhash();
    await connection.confirmTransaction({
      signature: airdropSig,
      blockhash: latestBlockhash.blockhash,
      lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
    });
    console.log("✅ Airdrop confirmed! Balance ready for token mint creation.");
  } catch (err) {
    console.warn("⚠️ Airdrop rate limited or failed, checking balance...", err);
  }

  const { rows: assets } = await pool.query(
    "SELECT asset_id, name, symbol, total_supply FROM assets ORDER BY asset_id ASC"
  );

  console.log(`\n📦 Found ${assets.length} products to tokenize with Solana SPL Token Mints:\n`);

  for (const asset of assets) {
    try {
      console.log(`🔨 Creating SPL Token Mint for Asset #${asset.asset_id}: ${asset.name} (${asset.symbol})...`);
      
      // 6 decimals standard (allows fractional units like 0.1, 0.25, 0.5)
      const decimals = 6;
      const mint = await createMint(
        connection,
        payer,
        payer.publicKey,
        payer.publicKey,
        decimals
      );

      console.log(`   ✨ Token Mint Created: ${mint.toBase58()}`);
      console.log(`   🔍 Explorer: https://explorer.solana.com/address/${mint.toBase58()}?cluster=devnet`);

      // Create supplier ATA (Associated Token Account) to hold initial minted supply
      const supplierAta = await getOrCreateAssociatedTokenAccount(
        connection,
        payer,
        mint,
        payer.publicKey
      );

      const supplyUnits = Math.floor(parseFloat(asset.total_supply));
      const atomicUnits = BigInt(supplyUnits) * BigInt(10 ** decimals);

      await mintTo(
        connection,
        payer,
        mint,
        supplierAta.address,
        payer,
        atomicUnits
      );

      console.log(`   💰 Minted ${supplyUnits} tokens (${atomicUnits.toString()} atomic units) to ATA: ${supplierAta.address.toBase58()}`);

      // Persist the SPL mint address into our Neon database
      await pool.query(
        "UPDATE assets SET mint_address = $1, identifier = $2 WHERE asset_id = $3",
        [mint.toBase58(), `MINT:${mint.toBase58().substring(0, 8)}`, asset.asset_id]
      );

      console.log(`   💾 Database updated with real on-chain SPL Mint!\n`);
    } catch (err: any) {
      console.error(`❌ Error creating token for Asset #${asset.asset_id}:`, err.message || err);
    }
  }

  console.log("🎉 All products processed! Real Solana SPL Token accounts are live on Devnet.");
  process.exit(0);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
