import { pool } from "../db/pool";

export class OracleService {
  /**
   * Seed realistic multi-timeframe price tick data (1D, 1W, 1M, 1Y, ALL)
   * if the asset_price_ticks table is empty or sparse.
   */
  public static async seedHistoricalTicksIfEmpty(): Promise<void> {
    try {
      const { rows: countRows } = await pool.query("SELECT COUNT(*) FROM asset_price_ticks");
      const count = parseInt(countRows[0].count, 10);
      if (count > 50) {
        return;
      }

      console.log("[OracleService] Seeding multi-timeframe price ticks for all assets...");
      const { rows: assets } = await pool.query("SELECT asset_id, price_usd FROM assets");

      const now = Date.now();
      const intervals = [
        // 1D (hourly for last 24h = 24 points)
        { hoursAgo: 24, stepHours: 1, maxVariance: 0.035 },
        // 1W (every 6h for last 7d = 28 points)
        { hoursAgo: 7 * 24, stepHours: 6, maxVariance: 0.06 },
        // 1M (daily for last 30d = 30 points)
        { hoursAgo: 30 * 24, stepHours: 24, maxVariance: 0.12 },
        // 1Y (weekly for last 52w = 52 points)
        { hoursAgo: 365 * 24, stepHours: 168, maxVariance: 0.28 },
      ];

      for (const asset of assets) {
        const basePrice = parseFloat(asset.price_usd);
        const assetId = asset.asset_id;

        for (const config of intervals) {
          const totalSteps = Math.floor(config.hoursAgo / config.stepHours);
          for (let step = totalSteps; step >= 0; step--) {
            const timeMs = now - (step * config.stepHours * 3600 * 1000);
            const date = new Date(timeMs);
            // Realistic geometric Brownian drift
            const progress = (totalSteps - step) / totalSteps;
            const trend = (progress - 0.5) * config.maxVariance;
            const noise = (Math.sin(step * 0.7) * 0.5 + Math.cos(step * 1.3) * 0.5) * (config.maxVariance * 0.5);
            const factor = 1 + trend + noise;
            const tickPrice = Math.max(1, basePrice * factor).toFixed(4);

            await pool.query(
              `INSERT INTO asset_price_ticks (asset_id, tick_time, price_usd)
               VALUES ($1, $2, $3)`,
              [assetId, date, tickPrice]
            );
          }
        }
      }
      console.log("[OracleService] Multi-timeframe price history seeded successfully!");
    } catch (err) {
      console.error("[OracleService] Error seeding price history:", err);
    }
  }

  /**
   * Periodically updates price ticks with realistic oracle drift (+/- 0.15% to 0.4%)
   * and updates 24h change percentages in the database.
   */
  public static async refreshPrices(): Promise<void> {
    try {
      const { rows: assets } = await pool.query(
        "SELECT asset_id, price_usd, change_24h_pct FROM assets"
      );

      const now = new Date();
      for (const asset of assets) {
        const currentPrice = parseFloat(asset.price_usd);
        // Small realistic market drift between -0.25% and +0.35%
        const deltaPct = (Math.random() * 0.6 - 0.25) / 100;
        const newPrice = parseFloat((currentPrice * (1 + deltaPct)).toFixed(4));
        const updatedChange = parseFloat((parseFloat(asset.change_24h_pct) + deltaPct * 10).toFixed(2));

        // 1. Record new tick in history
        await pool.query(
          "INSERT INTO asset_price_ticks (asset_id, tick_time, price_usd) VALUES ($1, $2, $3)",
          [asset.asset_id, now, newPrice]
        );

        // 2. Update live asset price in catalog
        await pool.query(
          "UPDATE assets SET price_usd = $1, change_24h_pct = $2 WHERE asset_id = $3",
          [newPrice, updatedChange, asset.asset_id]
        );
      }
    } catch (err) {
      console.error("[OracleService] Error refreshing oracle prices:", err);
    }
  }

  public static startTickWorker(intervalMs: number = 60000): void {
    console.log(`[OracleService] Starting price oracle worker (every ${intervalMs / 1000}s)`);
    // Seed initial history immediately if empty
    this.seedHistoricalTicksIfEmpty();

    setInterval(() => {
      this.refreshPrices();
    }, intervalMs);
  }
}
