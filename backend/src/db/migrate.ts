import fs from "fs";
import path from "path";
import { pool } from "./pool";

async function runMigration() {
  console.log("Connecting to Neon PostgreSQL and executing schema...");
  const schemaSql = fs.readFileSync(path.join(__dirname, "schema.sql"), "utf-8");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(schemaSql);

    // Check if initial assets exist; if not, seed with production catalog
    const { rows } = await client.query("SELECT COUNT(*) FROM assets");
    if (parseInt(rows[0].count, 10) === 0) {
      console.log("Seeding initial production RWA catalog...");
      await client.query(`
        INSERT INTO assets (
          asset_id, name, symbol, category, grade, specification, identifier,
          custodian_id, vault_location, price_usd, change_24h_pct,
          total_supply, available_supply, liquidity_usd, volume_24h_usd, image_asset
        ) VALUES
        (1, 'NVIDIA GPU', 'H100', 'GPU', 'Enterprise H100', '80GB HBM3 · AI Cluster Share', 'LOT SXM5-80G', 'CUST-SV-01', 'Silicon Valley Tier-4 Datacenter', 742.18, 3.76, 10000, 8420, 9800000, 2900000, 'assets/images/gpu.jpg'),
        (2, 'Gold (RWA)', 'AU99', 'Gold', '99.99% Fine Bullion', '1 Troy Oz · Zurich Vault Custody', 'AU-VAULT-771', 'CUST-ZH-99', 'Zurich Bullion Depository', 1942.32, 1.32, 500, 310, 15000000, 4200000, NULL),
        (3, 'iPhone 15 Pro', 'IPH15', 'Phones', 'Sealed Grade A', '256 GB · Natural Titanium · Vault Custody', '•••• 4821', 'CUST-NY-14', 'New York Vault Storage', 982.40, 4.21, 150, 42, 500000, 120000, 'assets/images/iphone18.jpg'),
        (4, 'Tesla Model S', 'TSLA', 'Cars', 'Plaid 2024', 'Tri-Motor AWD · Tokenized Autonomous Fleet', 'VIN 5YJSA1E2', 'CUST-CA-08', 'Fremont Bonded Facility', 68420.00, 2.19, 20, 7, 2400000, 890000, 'assets/images/F1_car.jpg'),
        (5, 'DDR5 RAM 32GB', 'RAM', 'RAM', 'ECC Reg 6400', '32 GB · 6400 MHz High-Speed Datacenter', 'LOT RAM-991', 'CUST-SV-01', 'Silicon Valley Component Depot', 256.90, 2.48, 2500, 1890, 850000, 310000, 'assets/images/ram.jpg')
      `);
      console.log("Production RWA catalog successfully seeded!");
    }

    await client.query("COMMIT");
    console.log("Migration completed successfully!");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Migration failed:", error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();
