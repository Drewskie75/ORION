import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // @ts-ignore
  const program = anchor.workspace.OrionProtocol as Program<any>;
  console.log("Connecting to Orion Protocol at:", program.programId.toBase58());

  const assetsToSeed = [
    {
      id: 1,
      name: "NVIDIA GPU",
      symbol: "H100",
      category: "GPU",
      conditionGrade: 2,
      priceUsdc: 742180000, // $742.18 (6 decimals)
      units: 10000,
    },
    {
      id: 2,
      name: "Gold (RWA)",
      symbol: "AU99",
      category: "Gold",
      conditionGrade: 3,
      priceUsdc: 1942320000, // $1,942.32
      units: 500,
    },
    {
      id: 3,
      name: "iPhone 15 Pro",
      symbol: "IPH15",
      category: "Phones",
      conditionGrade: 1,
      priceUsdc: 982400000, // $982.40
      units: 150,
    },
    {
      id: 4,
      name: "Tesla Model S",
      symbol: "TSLA",
      category: "Cars",
      conditionGrade: 2,
      priceUsdc: 68420000000, // $68,420.00
      units: 20,
    },
    {
      id: 5,
      name: "DDR5 RAM 32GB",
      symbol: "RAM",
      category: "RAM",
      conditionGrade: 2,
      priceUsdc: 256900000, // $256.90
      units: 2500,
    },
  ];

  console.log(`Seeding ${assetsToSeed.length} production RWA inventory listings on Solana Devnet...`);

  for (const asset of assetsToSeed) {
    console.log(`- Prepared asset: ${asset.name} (${asset.symbol}) at $${(asset.priceUsdc / 1_000_000).toFixed(2)}`);
  }

  console.log("Assets prepared for on-chain minting & indexing!");
}

main().catch((err) => {
  console.error("Seeding error:", err);
  process.exit(1);
});
