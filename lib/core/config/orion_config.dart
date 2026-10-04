class OrionConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'ORION_API_BASE_URL',
  );

  /// Deployed Solana Orion RWA Protocol Program ID
  static const String programId = String.fromEnvironment(
    'ORION_PROGRAM_ID',
    defaultValue: '9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS',
  );

  /// Target Solana Network Cluster
  static const String cluster = String.fromEnvironment(
    'ORION_SOLANA_CLUSTER',
    defaultValue: 'devnet',
  );

  /// Public Solana Devnet RPC
  static const String rpcUrl = String.fromEnvironment(
    'ORION_SOLANA_RPC_URL',
    defaultValue: 'https://api.devnet.solana.com',
  );
  static const String wsUrl = String.fromEnvironment(
    'ORION_SOLANA_WS_URL',
    defaultValue: 'wss://api.devnet.solana.com',
  );

  /// Default Connected User Wallet on Devnet
  static const String defaultUserWallet =
      'mQ7Q6vTLk6BuZwWRpDRHtjyJ6oggGS5ZAs9fyLz9VoZ';

  /// Standard Solana Devnet USDC Mint
  static const String devnetUsdcMint = String.fromEnvironment(
    'ORION_USDC_MINT',
    defaultValue: '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU',
  );

  /// Default Treasury Address
  static const String treasuryPubkey = String.fromEnvironment(
    'ORION_TREASURY_PUBKEY',
    defaultValue: 'mQ7Q6vTLk6BuZwWRpDRHtjyJ6oggGS5ZAs9fyLz9VoZ',
  );

  /// Primary Backend REST API host
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _apiBaseUrlOverride.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    return 'https://orion-backend-59qa.onrender.com/api';
  }

  /// Candidate URLs for automatic fallback in OrionApiService
  static List<String> get candidateApiUrls {
    return [apiBaseUrl];
  }

  /// Helper to generate Solana Explorer URL for transactions
  static String getExplorerTxUrl(String txSignature) {
    return 'https://explorer.solana.com/tx/$txSignature?cluster=$cluster';
  }

  /// Helper to generate Solana Explorer URL for program address
  static String getExplorerProgramUrl() {
    return 'https://explorer.solana.com/address/$programId?cluster=$cluster';
  }
}
