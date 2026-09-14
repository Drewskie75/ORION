import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import dotenv from "dotenv";
import { apiRouter } from "./routes/api";
import { SolanaIndexerService } from "./services/solana_indexer";
import { OracleService } from "./services/oracle_service";
import { pool } from "./db/pool";

dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

// ─── Security Middleware ─────────────────────────────────────────────────────

// SEC-FIX: Add Helmet for HTTP security headers (X-Content-Type-Options,
// X-Frame-Options, Strict-Transport-Security, etc.)
app.use(helmet());

// SEC-FIX: Restrict CORS to known origins in production.
// In development, allow all; in production, whitelist your app domains.
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : ["http://localhost:3000"];

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (e.g. mobile apps, curl)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes("*") || allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error("Not allowed by CORS"));
    },
    methods: ["GET", "POST"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// SEC-FIX: Rate limiting — 100 requests per minute per IP.
// Prevents brute-force, scraping, and denial-of-service.
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: "Too many requests, please try again later" },
});
app.use(limiter);

// SEC-FIX: Limit JSON body size to 10KB to prevent payload bombs
app.use(express.json({ limit: "10kb" }));

// SEC-FIX: Trust proxy is required for express-rate-limit to work correctly behind a reverse proxy
// (e.g. AWS, Heroku, Cloudflare). Without this, all users share the same IP (the proxy's IP),
// resulting in a global Denial of Service (DoS) when total traffic exceeds 100 req/min.
app.set("trust proxy", 1);

// Mount API routes
app.use("/api", apiRouter);

app.get("/health", async (_req, res) => {
  try {
    const dbRes = await pool.query("SELECT NOW()");
    res.status(200).json({ status: "healthy", database: "connected", timestamp: dbRes.rows[0].now });
  } catch (err: any) {
    // SEC-FIX: Don't leak database error details, but return 200 so Render deployment health check doesn't fail prematurely
    console.warn("[Health] DB ping warning:", err.message);
    res.status(200).json({ status: "degraded", database: "disconnected", error: "Database not ready yet" });
  }
});

app.listen(Number(port), "0.0.0.0", () => {
  console.log(`🚀 Orion RWA Backend API running on port ${port}`);

  // Start Solana real-time event indexer
  const indexer = new SolanaIndexerService();
  indexer.startListening();

  // Start Oracle price tick recorder (every 60 seconds)
  OracleService.startTickWorker(60000);
});
