import fs from "fs";
import path from "path";
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import { getOrCreateAssociatedTokenAccount, transfer } from "@solana/spl-token";
import dotenv from "dotenv";

dotenv.config();

export class SolanaSettlementService {
  private static connection: Connection | null = null;
  private static custodianKeypair: Keypair | null = null;

  private static getConnection(): Connection {
    if (!this.connection) {
      const rpcUrl = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
      this.connection = new Connection(rpcUrl, "confirmed");
    }
    return this.connection;
  }

  public static getCustodianKeypair(): Keypair {
    if (this.custodianKeypair) {
      return this.custodianKeypair;
    }

    // Try loading from environment variable
    if (process.env.CUSTODIAN_PRIVATE_KEY) {
      try {
        const raw = process.env.CUSTODIAN_PRIVATE_KEY.trim();
        const parsed = JSON.parse(raw);
        this.custodianKeypair = Keypair.fromSecretKey(new Uint8Array(parsed));
        return this.custodianKeypair;
      } catch (e) {
        console.warn("[SolanaSettlement] Failed to parse CUSTODIAN_PRIVATE_KEY from .env:", e);
      }
    }

    // Fallback: try loading from custodian_keypair.json
    const keyPath = path.join(process.cwd(), "custodian_keypair.json");
    if (fs.existsSync(keyPath)) {
      try {
        const content = fs.readFileSync(keyPath, "utf-8");
        const parsed = JSON.parse(content);
        this.custodianKeypair = Keypair.fromSecretKey(new Uint8Array(parsed));
        return this.custodianKeypair;
      } catch (e) {
        console.warn("[SolanaSettlement] Failed to read custodian_keypair.json:", e);
      }
    }

    // Fallback: generate temporary keypair
    console.warn("[SolanaSettlement] Using generated temporary keypair");
    this.custodianKeypair = Keypair.generate();
    return this.custodianKeypair;
  }

  /**
   * Transfer real fractional SPL RWA tokens from custodian reserve to the buyer's ATA on Devnet.
   * @param buyerWallet The base58 address of the buyer
   * @param mintAddress The base58 SPL token mint address of the RWA product
   * @param amount The fractional quantity (e.g. 0.25, 0.5, 1.0)
   * @param decimals The token decimals (default: 6)
   */
  public static async transferFractionalRwa({
    buyerWallet,
    mintAddress,
    amount,
    decimals = 6,
  }: {
    buyerWallet: string;
    mintAddress: string;
    amount: number;
    decimals?: number;
  }): Promise<{
    success: boolean;
    txHash: string;
    buyerAta?: string;
    atomicUnits?: string;
    error?: string;
  }> {
    try {
      const conn = this.getConnection();
      const payer = this.getCustodianKeypair();

      let buyerPubkey: PublicKey;
      try {
        buyerPubkey = new PublicKey(buyerWallet);
      } catch {
        return {
          success: false,
          txHash: "",
          error: "Invalid buyer Solana public key",
        };
      }

      let mintPubkey: PublicKey;
      try {
        mintPubkey = new PublicKey(mintAddress);
      } catch {
        return {
          success: false,
          txHash: "",
          error: "Invalid SPL Token Mint public key",
        };
      }

      console.log(`[SolanaSettlement] 🚀 Settling on-chain purchase of ${amount} shares...`);
      console.log(`  Buyer: ${buyerPubkey.toBase58()}`);
      console.log(`  Mint : ${mintPubkey.toBase58()}`);

      // 1. Get or create custodian's ATA (source)
      const custodianAta = await getOrCreateAssociatedTokenAccount(
        conn,
        payer,
        mintPubkey,
        payer.publicKey
      );

      // 2. Get or create buyer's ATA (destination)
      // Note: The custodian/payer pays the rent fee to create the ATA if it does not exist yet!
      const buyerAta = await getOrCreateAssociatedTokenAccount(
        conn,
        payer,
        mintPubkey,
        buyerPubkey
      );

      // 3. Compute atomic units with 6 decimals (e.g. 0.25 -> 250,000 units)
      const atomicUnits = BigInt(Math.round(amount * Math.pow(10, decimals)));

      console.log(
        `  Transferring ${atomicUnits.toString()} atomic units from ${custodianAta.address.toBase58()} -> ${buyerAta.address.toBase58()}...`
      );

      // 4. Execute on-chain transfer
      const signature = await transfer(
        conn,
        payer,
        custodianAta.address,
        buyerAta.address,
        payer,
        atomicUnits
      );

      console.log(`  ✅ On-Chain Transfer Confirmed! Signature: ${signature}`);

      return {
        success: true,
        txHash: signature,
        buyerAta: buyerAta.address.toBase58(),
        atomicUnits: atomicUnits.toString(),
      };
    } catch (err: any) {
      console.error("[SolanaSettlement] Transfer error:", err.message || err);
      return {
        success: false,
        txHash: "",
        error: err.message || "Solana SPL Token transfer failed",
      };
    }
  }
}
