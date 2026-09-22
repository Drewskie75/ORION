import fs from "fs";
import path from "path";
import os from "os";
import { Connection, Keypair, LAMPORTS_PER_SOL, PublicKey } from "@solana/web3.js";
import { createMint, getOrCreateAssociatedTokenAccount, mintTo } from "@solana/spl-token";

// Define all 6 physical RWA assets in the Orion Protocol app
const ORION_ASSETS = [
  {
    assetId: 1,
    name: "NVIDIA GPU",
    symbol: "H100",
    category: "GPU",
    supplyUnits: 10000,
    decimals: 6,
    priceUsd: 742.18,
  },
  {
    assetId: 2,
    name: "Gold (RWA)",
    symbol: "AU99",
    category: "Gold",
    supplyUnits: 500,
    decimals: 6,
    priceUsd: 1942.32,
  },
  {
    assetId: 3,
    name: "iPhone 15 Pro",
    symbol: "IPH15",
    category: "Phones",
    supplyUnits: 150,
    decimals: 6,
    priceUsd: 982.40,
  },
  {
    assetId: 4,
    name: "Tesla Model S",
    symbol: "TSLA",
    category: "Cars",
    supplyUnits: 20,
    decimals: 6,
    priceUsd: 68420.00,
  },
  {
    assetId: 5,
    name: "DDR5 RAM 32GB",
    symbol: "RAM",
    category: "RAM",
    supplyUnits: 2500,
    decimals: 6,
    priceUsd: 256.90,
  },
  {
    assetId: 6,
    name: "Silver (RWA)",
    symbol: "AG99",
    category: "Gold",
    supplyUnits: 5000,
    decimals: 6,
    priceUsd: 24.18,
  },
];

async function main() {
  console.log("======================================================================");
  console.log("   🪐 ORION PROTOCOL - SOLANA DEVNET TOKEN MINT CREATOR (WSL) 🪐     ");
  console.log("======================================================================\n");

  const rpcUrl = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
  const connection = new Connection(rpcUrl, "confirmed");

  // Load keypair from default Solana CLI path (~/.config/solana/id.json)
  const defaultKeypairPath = path.join(os.homedir(), ".config", "solana", "id.json");
  let payer: Keypair;

  if (fs.existsSync(defaultKeypairPath)) {
    console.log(`📁 Loading existing Solana keypair from: ${defaultKeypairPath}`);
    const keyData = JSON.parse(fs.readFileSync(defaultKeypairPath, "utf-8"));
    payer = Keypair.fromSecretKey(new Uint8Array(keyData));
  } else {
    console.log("⚠️ No ~/.config/solana/id.json found, generating temporary keypair...");
    payer = Keypair.generate();
  }

  console.log(`👤 Authority Public Key: ${payer.publicKey.toBase58()}`);

  const balance = await connection.getBalance(payer.publicKey);
  console.log(`💰 Balance: ${(balance / LAMPORTS_PER_SOL).toFixed(4)} SOL`);

  if (balance < 0.3 * LAMPORTS_PER_SOL) {
    console.log("🪂 Requesting Devnet airdrop (2 SOL)...");
    try {
      const airdropSig = await connection.requestAirdrop(payer.publicKey, 2 * LAMPORTS_PER_SOL);
      const latest = await connection.getLatestBlockhash();
      await connection.confirmTransaction({
        signature: airdropSig,
        blockhash: latest.blockhash,
        lastValidBlockHeight: latest.lastValidBlockHeight,
      });
      console.log("✅ Airdrop confirmed!");
    } catch (e: any) {
      console.warn("⚠️ Airdrop request rate limited. Continuing with existing balance...");
    }
  }

  const results: any[] = [];

  for (const asset of ORION_ASSETS) {
    console.log(`\n----------------------------------------------------------------------`);
    console.log(`▶ Creating SPL Token for Asset #${asset.assetId}: ${asset.name} (${asset.symbol})`);
    console.log(`  Decimals: ${asset.decimals} (enables fractions like 0.1, 0.25, 0.5)`);

    try {
      const mint = await createMint(
        connection,
        payer,
        payer.publicKey,
        payer.publicKey,
        asset.decimals
      );

      console.log(`  ✨ Token Mint: ${mint.toBase58()}`);
      console.log(`  🔍 Explorer  : https://explorer.solana.com/address/${mint.toBase58()}?cluster=devnet`);

      // Create Associated Token Account for the physical reserve custodian
      const custodianAta = await getOrCreateAssociatedTokenAccount(
        connection,
        payer,
        mint,
        payer.publicKey
      );

      console.log(`  🏦 Custodian ATA: ${custodianAta.address.toBase58()}`);

      // Mint initial supply
      const atomicUnits = BigInt(asset.supplyUnits) * BigInt(10 ** asset.decimals);
      await mintTo(
        connection,
        payer,
        mint,
        custodianAta.address,
        payer,
        atomicUnits
      );

      console.log(`  💰 Minted ${asset.supplyUnits} units (${atomicUnits.toString()} atomic units)`);

      // Try updating local backend database via API if running
      try {
        const response = await fetch(`http://localhost:4000/api/assets/${asset.assetId}/mint`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ mintAddress: mint.toBase58() }),
        });
        const resJson = await response.json();
        if (resJson.success) {
          console.log(`  💾 Updated Neon Database via Orion API!`);
        }
      } catch (_) {}

      results.push({
        assetId: asset.assetId,
        name: asset.name,
        symbol: asset.symbol,
        mint: mint.toBase58(),
        custodianAta: custodianAta.address.toBase58(),
        supply: asset.supplyUnits,
        decimals: asset.decimals,
        explorer: `https://explorer.solana.com/address/${mint.toBase58()}?cluster=devnet`,
      });
    } catch (err: any) {
      console.error(`❌ Failed to create token for ${asset.name}:`, err.message || err);
    }
  }

  const manifestPath = path.join(process.cwd(), "rwa_tokens_manifest.json");
  fs.writeFileSync(manifestPath, JSON.stringify({ network: "devnet", tokens: results }, null, 2));

  console.log(`\n======================================================================`);
  console.log(`🎉 Done! Created ${results.length}/${ORION_ASSETS.length} SPL Token Mints on Devnet.`);
  console.log(`📁 Manifest saved to: ${manifestPath}`);
  console.log(`======================================================================\n`);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
