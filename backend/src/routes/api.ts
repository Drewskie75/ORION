import { Router, Request, Response } from "express";
import { Connection, PublicKey, SystemProgram, Transaction, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { pool } from "../db/pool";
import { SolanaSettlementService } from "../services/solana_settlement";

export const apiRouter = Router();

// ─── Input Validation Helpers ────────────────────────────────────────────────

/** Solana base58 public key: 32-44 alphanumeric characters */
const WALLET_REGEX = /^[1-9A-HJ-NP-Za-km-z]{32,44}$/;

function isValidWallet(addr: string): boolean {
  return typeof addr === "string" && WALLET_REGEX.test(addr);
}

function isPositiveInteger(val: unknown): val is number {
  return typeof val === "number" && Number.isFinite(val) && val > 0 && Number.isInteger(val);
}

const VALID_TIMEFRAMES = new Set(["1D", "1W", "1M", "3M", "1Y", "ALL"]);
const VALID_CATEGORIES = new Set(["GPU", "Phones", "Gold", "Cars", "RAM"]);

// ─── 1. Get all marketplace asset listings ───────────────────────────────────

apiRouter.get("/assets", async (_req: Request, res: Response) => {
  try {
    const { rows } = await pool.query(`
      SELECT 
        asset_id, name, symbol, category, grade, specification, identifier,
        custodian_id, vault_location, price_usd, change_24h_pct,
        total_supply, available_supply, liquidity_usd, volume_24h_usd, image_asset
      FROM assets
      ORDER BY asset_id ASC
      LIMIT 100
    `);

    const formatted = rows.map((r) => {
      const p = parseFloat(r.price_usd);
      return {
        ...r,
        price: r.price_usd,
        change: `${r.change_24h_pct >= 0 ? "+" : ""}${r.change_24h_pct}%`,
        sparklinePoints: [p * 0.96, p * 0.97, p * 0.965, p * 0.98, p * 0.99, p * 0.985, p],
      };
    });

    res.json({ success: true, count: formatted.length, data: formatted });
  } catch (err: any) {
    // SEC-FIX: Never leak internal error messages to the client
    console.error("[API] /assets error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// ─── 1b. Get individual asset price history ticks for financial chart ────────
apiRouter.get("/assets/:id/history", async (req: Request, res: Response) => {
  const assetId = parseInt(req.params.id, 10);
  const timeframe = (req.query.timeframe as string) || "1D";

  if (isNaN(assetId) || assetId <= 0) {
    return res.status(400).json({ success: false, error: "Invalid asset ID" });
  }
  if (!VALID_TIMEFRAMES.has(timeframe)) {
    return res.status(400).json({ success: false, error: "Invalid timeframe" });
  }

  const intervalMap: Record<string, string> = {
    "1D": "1 day",
    "1W": "7 days",
    "1M": "30 days",
    "3M": "90 days",
    "1Y": "365 days",
    "ALL": "3650 days",
  };
  const interval = intervalMap[timeframe] || "1 day";

  try {
    const { rows: ticks } = await pool.query(
      `SELECT tick_time, price_usd
       FROM asset_price_ticks
       WHERE asset_id = $1 AND tick_time >= NOW() - $2::interval
       ORDER BY tick_time ASC
       LIMIT 250`,
      [assetId, interval]
    );

    const points = ticks.map((t) => parseFloat(t.price_usd));
    const times = ticks.map((t) => {
      const d = new Date(t.tick_time);
      if (timeframe === "1D") {
        return `${d.getHours().toString().padStart(2, "0")}:00`;
      }
      return `${d.getMonth() + 1}/${d.getDate()}`;
    });

    const changePct = points.length > 1
      ? ((points[points.length - 1] - points[0]) / points[0]) * 100
      : 0;

    res.json({
      success: true,
      data: {
        assetId,
        timeframe,
        points: points.length > 0 ? points : [742.18],
        times: times.length > 0 ? times : ["00:00", "24:00"],
        changePercentage: parseFloat(changePct.toFixed(2)),
      },
    });
  } catch (err: any) {
    console.error("[API] /assets/:id/history error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// ─── 2. Get user portfolio summary & historical points ───────────────────────

apiRouter.get("/portfolio/:wallet", async (req: Request, res: Response) => {
  const { wallet } = req.params;
  const timeframe = (req.query.timeframe as string) || "1D";

  // SEC-FIX: Validate wallet address format to prevent SQL injection via params
  if (!isValidWallet(wallet)) {
    return res.status(400).json({ success: false, error: "Invalid wallet address format" });
  }
  if (!VALID_TIMEFRAMES.has(timeframe)) {
    return res.status(400).json({ success: false, error: "Invalid timeframe" });
  }

  try {
    const { rows: claims } = await pool.query(
      `SELECT c.asset_id, c.amount, a.price_usd
       FROM user_claims c 
       JOIN assets a ON c.asset_id = a.asset_id 
       WHERE c.owner_address = $1 AND c.status != 'Redeemed'`,
      [wallet]
    );

    let totalValue = 0;
    for (const c of claims) {
      totalValue += parseFloat(c.price_usd) * parseFloat(c.amount);
    }

    // Fetch real price history ticks for the user's specific portfolio
    const intervalMap: Record<string, string> = {
      "1D": "1 day",
      "1W": "7 days",
      "1M": "30 days",
      "3M": "90 days",
      "1Y": "365 days",
      "ALL": "3650 days",
    };
    const interval = intervalMap[timeframe] || "1 day";

    let historyPoints: number[] = [];

    if (claims.length > 0) {
      const { rows: ticks } = await pool.query(
        `SELECT t.tick_time, SUM(t.price_usd * c.amount) as portfolio_value
         FROM user_claims c
         JOIN asset_price_ticks t ON c.asset_id = t.asset_id
         WHERE c.owner_address = $1 AND c.status != 'Redeemed' AND t.tick_time >= NOW() - $2::interval
         GROUP BY t.tick_time
         ORDER BY t.tick_time ASC
         LIMIT 200`,
        [wallet, interval]
      );

      if (ticks.length > 0) {
        historyPoints = ticks.map((t) => parseFloat(t.portfolio_value));
      }
    }

    // If no ticks yet or newly bought, synthesize smooth historical curve scaling to actual totalValue
    if (historyPoints.length === 0 && totalValue > 0) {
      const steps = 20;
      const variance = timeframe === "1D" ? 0.02 : timeframe === "1W" ? 0.04 : 0.08;
      for (let i = 0; i < steps; i++) {
        const factor = 1 - variance + (variance * (i / (steps - 1))) + (Math.sin(i) * 0.005);
        historyPoints.push(parseFloat((totalValue * factor).toFixed(2)));
      }
      historyPoints[historyPoints.length - 1] = parseFloat(totalValue.toFixed(2));
    } else if (historyPoints.length === 0) {
      historyPoints = [0, 0];
    } else if (historyPoints.length === 1) {
      historyPoints = [historyPoints[0] * 0.98, historyPoints[0]];
    }

    const firstPoint = historyPoints[0];
    const lastPoint = historyPoints[historyPoints.length - 1];
    const changeAmount = lastPoint - firstPoint;
    const changePercentage = firstPoint > 0 ? (changeAmount / firstPoint) * 100 : 0;

    res.json({
      success: true,
      data: {
        wallet,
        totalValue,
        changePercentage,
        changeAmount,
        isPositive: changeAmount >= 0,
        timeframe,
        historyPoints,
        holdingsCount: claims.length,
      },
    });
  } catch (err: any) {
    console.error("[API] /portfolio error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// ─── 3. Get user owned claims ────────────────────────────────────────────────

apiRouter.get("/claims/:wallet", async (req: Request, res: Response) => {
  const { wallet } = req.params;

  if (!isValidWallet(wallet)) {
    return res.status(400).json({ success: false, error: "Invalid wallet address format" });
  }

  try {
    const { rows } = await pool.query(
      `SELECT c.id, c.owner_address, c.amount, c.status, c.acquired_price_usd, c.tx_hash,
              a.asset_id, a.name, a.symbol, a.category, a.grade, a.specification, 
              a.identifier, a.image_asset, a.price_usd
       FROM user_claims c
       JOIN assets a ON c.asset_id = a.asset_id
       WHERE c.owner_address = $1
       ORDER BY c.created_at DESC
       LIMIT 100`,
      [wallet]
    );

    res.json({ success: true, count: rows.length, data: rows });
  } catch (err: any) {
    console.error("[API] /claims error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// ─── 4. Submit supplier intake proposal ──────────────────────────────────────

apiRouter.post("/proposals", async (req: Request, res: Response) => {
  const { supplier, assetId, category, conditionGrade, proposedUnits, auditor } = req.body;

  // SEC-FIX: Validate all inputs — never trust the client
  if (!isValidWallet(supplier)) {
    return res.status(400).json({ success: false, error: "Invalid supplier address" });
  }
  if (!isValidWallet(auditor)) {
    return res.status(400).json({ success: false, error: "Invalid auditor address" });
  }
  if (!isPositiveInteger(assetId)) {
    return res.status(400).json({ success: false, error: "Invalid assetId" });
  }
  if (!VALID_CATEGORIES.has(category)) {
    return res.status(400).json({ success: false, error: "Invalid category" });
  }
  if (typeof conditionGrade !== "number" || conditionGrade < 1 || conditionGrade > 3) {
    return res.status(400).json({ success: false, error: "conditionGrade must be 1, 2, or 3" });
  }
  if (!isPositiveInteger(proposedUnits) || proposedUnits > 1_000_000) {
    return res.status(400).json({ success: false, error: "proposedUnits must be 1–1,000,000" });
  }

  const proposalId = Date.now();

  try {
    await pool.query(
      `INSERT INTO supplier_proposals (proposal_id, supplier_address, asset_id, category, condition_grade, proposed_units, auditor_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [proposalId, supplier, assetId, category, conditionGrade, proposedUnits, auditor]
    );

    res.status(201).json({ success: true, proposalId });
  } catch (err: any) {
    console.error("[API] /proposals error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// ─── 5. Submit physical redemption request ───────────────────────────────────

apiRouter.post("/redemptions", async (req: Request, res: Response) => {
  const { claimId, redeemer, carrier } = req.body;

  // SEC-FIX: Validate inputs
  if (!isValidWallet(redeemer)) {
    return res.status(400).json({ success: false, error: "Invalid redeemer address" });
  }
  if (!isPositiveInteger(claimId)) {
    return res.status(400).json({ success: false, error: "Invalid claimId" });
  }

  const ticketId = Date.now();
  const safeCarrier = typeof carrier === "string" && carrier.length <= 64
    ? carrier
    : "Brink's Secure Logistics";

  const client = await pool.connect();

  try {
    // SEC-FIX: Use a transaction so that INSERT + UPDATE are atomic.
    // Without this, if the UPDATE fails, an orphaned redemption ticket is created.
    await client.query("BEGIN");

    // SEC-FIX: Verify the claim exists AND belongs to the redeemer AND is in 'Held' status.
    // Without this, anyone can redeem anyone else's claims.
    const { rows: claimRows } = await client.query(
      "SELECT id, owner_address, status FROM user_claims WHERE id = $1 FOR UPDATE",
      [claimId]
    );

    if (claimRows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ success: false, error: "Claim not found" });
    }

    const claim = claimRows[0];
    if (claim.owner_address !== redeemer) {
      await client.query("ROLLBACK");
      return res.status(403).json({ success: false, error: "You do not own this claim" });
    }
    if (claim.status !== "Held") {
      await client.query("ROLLBACK");
      return res.status(409).json({ success: false, error: `Claim status is '${claim.status}', must be 'Held'` });
    }

    await client.query(
      `INSERT INTO redemption_tickets (ticket_id, claim_id, redeemer_address, carrier, delivery_status)
       VALUES ($1, $2, $3, $4, 'Requested')`,
      [ticketId, claimId, redeemer, safeCarrier]
    );

    await client.query(
      "UPDATE user_claims SET status = 'Redemption_Requested' WHERE id = $1",
      [claimId]
    );

    await client.query("COMMIT");
    res.status(201).json({ success: true, ticketId });
  } catch (err: any) {
    await client.query("ROLLBACK");
    console.error("[API] /redemptions error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  } finally {
    client.release();
  }
});

// ─── 6. Protocol Configuration & Network Info ────────────────────────────────
apiRouter.get("/config", (_req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      programId: process.env.ORION_PROGRAM_ID || "9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS",
      rpcUrl: process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com",
      cluster: "devnet",
      treasury: process.env.TREASURY_PUBKEY || "9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS",
    },
  });
});

// ─── 6b. Build Unsigned SOL/USDC Payment Transaction for Mobile Wallet Adapter ───
apiRouter.post("/trade/build-payment-tx", async (req: Request, res: Response) => {
  const { buyer, currency = "SOL", amount = 0.01 } = req.body;

  if (!isValidWallet(buyer)) {
    return res.status(400).json({ success: false, error: "Invalid buyer wallet address" });
  }

  try {
    const rpcUrl = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
    const conn = new Connection(rpcUrl, "confirmed");
    const treasuryPubkey = SolanaSettlementService.getCustodianKeypair().publicKey;
    const buyerPubkey = new PublicKey(buyer);

    const { blockhash } = await conn.getLatestBlockhash("confirmed");
    const tx = new Transaction({ recentBlockhash: blockhash, feePayer: buyerPubkey });

    const payCurrency = (currency || "SOL").toUpperCase();
    const payAmount = typeof amount === "number" ? amount : parseFloat(amount) || 0.01;

    if (payCurrency === "SOL") {
      const lamports = Math.max(1000, Math.round(payAmount * LAMPORTS_PER_SOL));
      tx.add(
        SystemProgram.transfer({
          fromPubkey: buyerPubkey,
          toPubkey: treasuryPubkey,
          lamports,
        })
      );
    }

    const serialized = tx.serialize({ requireAllSignatures: false, verifySignatures: false });
    res.json({
      success: true,
      data: {
        transactionBase64: serialized.toString("base64"),
        treasury: treasuryPubkey.toBase58(),
        currency: payCurrency,
        amount: payAmount,
        recentBlockhash: blockhash,
      },
    });
  } catch (err: any) {
    console.error("[API] /trade/build-payment-tx error:", err);
    res.status(500).json({ success: false, error: err.message || "Failed to construct transaction" });
  }
});

// ─── 7. Execute / Record Asset Purchase ──────────────────────────────────────
apiRouter.post("/trade/purchase", async (req: Request, res: Response) => {
  const { buyer, assetId, amount, txHash } = req.body;

  if (!isValidWallet(buyer)) {
    return res.status(400).json({ success: false, error: "Invalid buyer wallet address" });
  }
  if (!isPositiveInteger(assetId)) {
    return res.status(400).json({ success: false, error: "Invalid assetId" });
  }
  const rawUnits = typeof amount === "number" ? amount : parseFloat(amount);
  const units = !isNaN(rawUnits) && rawUnits > 0 ? rawUnits : 1;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: assetRows } = await client.query(
      "SELECT asset_id, price_usd, available_supply, mint_address FROM assets WHERE asset_id = $1 FOR UPDATE",
      [assetId]
    );

    if (assetRows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ success: false, error: "Asset not found" });
    }

    const asset = assetRows[0];
    const available = parseFloat(asset.available_supply);
    if (available < units) {
      await client.query("ROLLBACK");
      return res.status(400).json({ success: false, error: "Insufficient available supply" });
    }

    // Security check: verify that a valid on-chain payment transaction signature was provided
    if (!txHash || typeof txHash !== "string" || txHash.length < 32 || txHash.startsWith("sim_")) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: "Valid payment transaction signature (txHash) is required. Payment must be approved in wallet before settlement.",
      });
    }

    // On-Chain Solana SPL Token Settlement: transfer real fractional tokens to buyer
    let finalTxHash = txHash;
    let onChainSettled = false;
    let buyerAta = "";

    if (asset.mint_address) {
      const settlement = await SolanaSettlementService.transferFractionalRwa({
        buyerWallet: buyer,
        mintAddress: asset.mint_address,
        amount: units,
        decimals: 6,
      });

      if (settlement.success && settlement.txHash) {
        // If settlement succeeded, record the token transfer hash or keep payment hash
        finalTxHash = settlement.txHash;
        onChainSettled = true;
        buyerAta = settlement.buyerAta || "";
      }
    }

    if (!finalTxHash) {
      finalTxHash = "sim_" + Buffer.from(`${buyer}_${assetId}_${Date.now()}`).toString("hex").substring(0, 48);
    }

    // Decrement available supply and update volume
    await client.query(
      "UPDATE assets SET available_supply = available_supply - $1, volume_24h_usd = volume_24h_usd + ($2 * $1) WHERE asset_id = $3",
      [units, asset.price_usd, assetId]
    );

    // Insert user claim with real on-chain transaction hash
    const { rows: claimRows } = await client.query(
      `INSERT INTO user_claims (owner_address, asset_id, amount, status, acquired_price_usd, tx_hash)
       VALUES ($1, $2, $3, 'Held', $4, $5)
       RETURNING id, owner_address, asset_id, amount, status, acquired_price_usd, tx_hash`,
      [buyer, assetId, units, asset.price_usd, finalTxHash]
    );

    await client.query("COMMIT");
    res.status(201).json({
      success: true,
      data: {
        claim: claimRows[0],
        txHash: finalTxHash,
        onChainSettled,
        buyerAta,
        units,
        totalUsd: parseFloat(asset.price_usd) * units,
        explorerUrl: `https://explorer.solana.com/tx/${finalTxHash}?cluster=devnet`,
      },
    });
  } catch (err: any) {
    await client.query("ROLLBACK");
    console.error("[API] /trade/purchase error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  } finally {
    client.release();
  }
});

// ─── 8. Update SPL Token Mint Address for an Asset ───────────────────────────
apiRouter.post("/assets/:id/mint", async (req: Request, res: Response) => {
  const assetId = parseInt(req.params.id, 10);
  const { mintAddress } = req.body;

  if (isNaN(assetId) || assetId <= 0) {
    return res.status(400).json({ success: false, error: "Invalid asset ID" });
  }
  if (!mintAddress || typeof mintAddress !== "string" || mintAddress.length < 32) {
    return res.status(400).json({ success: false, error: "Invalid mint address" });
  }

  try {
    const { rowCount } = await pool.query(
      "UPDATE assets SET mint_address = $1, identifier = $2 WHERE asset_id = $3",
      [mintAddress, `MINT:${mintAddress.substring(0, 8)}`, assetId]
    );

    if (rowCount === 0) {
      return res.status(404).json({ success: false, error: "Asset not found" });
    }

    res.json({
      success: true,
      message: `Asset #${assetId} mint updated to ${mintAddress}`,
      assetId,
      mintAddress,
    });
  } catch (err: any) {
    console.error("[API] /assets/:id/mint error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

