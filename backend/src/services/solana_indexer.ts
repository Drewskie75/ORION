import { Connection, PublicKey } from "@solana/web3.js";
import { pool } from "../db/pool";
import dotenv from "dotenv";

dotenv.config();

export class SolanaIndexerService {
  private connection: Connection;
  private programId: PublicKey;

  constructor() {
    const rpcUrl = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
    const wsUrl = process.env.SOLANA_WS_URL || "wss://api.devnet.solana.com";
    this.connection = new Connection(rpcUrl, { wsEndpoint: wsUrl, commitment: "confirmed" });

    const programKeyStr = process.env.ORION_PROGRAM_ID || "9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS";
    this.programId = new PublicKey(programKeyStr);
  }

  public startListening() {
    console.log(`[Indexer] Subscribing to live Solana events for program: ${this.programId.toBase58()}`);

    try {
      this.connection.onLogs(
        this.programId,
        async (logs, ctx) => {
          if (logs.err) return;
          const signature = logs.signature;
          console.log(`[Indexer] Detected program activity: TX ${signature}`);

          for (const line of logs.logs) {
            if (line.includes("Purchased")) {
              await this.handlePurchaseEvent(signature, line);
            } else if (line.includes("Redemption #")) {
              await this.handleRedemptionEvent(signature, line);
            } else if (line.includes("Supplier proposal #")) {
              await this.handleSupplierProposal(signature, line);
            }
          }
        },
        "confirmed"
      );
    } catch (err) {
      console.error("[Indexer] Error establishing Solana WebSocket listener:", err);
    }
  }

  private async handlePurchaseEvent(signature: string, logLine: string) {
    console.log(`[Indexer] Indexing purchase event from TX: ${signature}`);
    try {
      // SEC-FIX: Extract actual purchase details from log and transaction.
      // Log format: "Purchased <units> units of listing #<listing_id> (Asset #<asset_id>). Gross: <gross_cost> USDC..."
      const match = logLine.match(/Purchased (\d+) units of listing #(\d+) \(Asset #(\d+)\)/);
      if (!match) {
        throw new Error("Failed to parse purchase log line");
      }

      const units = parseInt(match[1]);
      const listingId = parseInt(match[2]);
      const assetId = parseInt(match[3]);

      // Fetch transaction to identify the buyer (signer) and price
      const tx = await this.connection.getTransaction(signature, {
        maxSupportedTransactionVersion: 0,
      });

      if (!tx || !tx.transaction.message.staticAccountKeys[0]) {
        throw new Error("Transaction data unavailable or unparseable");
      }

      // In Solana, the first account key in the transaction is typically the fee payer / signer (buyer)
      const buyerAddress = tx.transaction.message.staticAccountKeys[0].toString();
      // Assume acquired price needs to be fetched from listing or transaction balances;
      // using a placeholder here that would be replaced by actual instruction parsing in prod.
      const acquiredPriceUsd = 0; // Replace with actual parsing

      await pool.query(
        `INSERT INTO user_claims (owner_address, asset_id, amount, status, acquired_price_usd, tx_hash)
         VALUES ($1, $2, $3, 'Held', $4, $5)
         ON CONFLICT DO NOTHING`,
        [buyerAddress, assetId, units, acquiredPriceUsd, signature]
      );
      
      console.log(`[Indexer] Successfully indexed purchase of ${units} units for ${buyerAddress}`);
    } catch (err) {
      console.error("[Indexer] Error saving purchase to database:", err);
    }
  }

  private async handleRedemptionEvent(signature: string, logLine: string) {
    console.log(`[Indexer] Indexing redemption update: ${logLine}`);
  }

  private async handleSupplierProposal(signature: string, logLine: string) {
    console.log(`[Indexer] Indexing supplier intake proposal: ${logLine}`);
  }
}
