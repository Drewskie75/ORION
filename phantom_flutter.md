# 👻 Phantom Wallet Integration in Flutter (Solana Mobile Stack)

> Complete technical guide and architecture documentation for integrating **Phantom Wallet** on Android using Flutter, the **Solana Mobile Stack (SMS)**, and the **Mobile Wallet Adapter (MWA) v2.0** specification.

---

## 📑 Table of Contents
1. [Overview & Protocol Architecture](#-overview--protocol-architecture)
2. [Android OS Setup (`AndroidManifest.xml`)](#-android-os-setup-androidmanifestxml)
3. [Dependencies (`pubspec.yaml`)](#-dependencies-pubspecyaml)
4. [Session Lifecycle & Authorization Flow](#-session-lifecycle--authorization-flow)
5. [The Multi-Signer Problem & Decoupled Signing Solution](#-the-multi-signer-problem--decoupled-signing-solution)
6. [Pre-flight Simulation & Blockhash Latency Optimization](#-pre-flight-simulation--blockhash-latency-optimization)
7. [Sign In With Solana (SIWS)](#-sign-in-with-solana-siws)
8. [Riverpod State Management](#-riverpod-state-management)
9. [Step-by-Step Developer Testing Guide on Devnet](#-step-by-step-developer-testing-guide-on-devnet)

---

## 🌟 Overview & Protocol Architecture

In mobile dApps built for Solana, web-based wallet adapters (such as browser extensions or deep-link redirect loops) provide poor user experience and security risks. 

StudyChain utilizes the **Solana Mobile Stack (SMS)** and the **Mobile Wallet Adapter (MWA) 2.0** standard. When interacting with **Phantom Wallet** on Android:
- The Flutter app acts as the **dApp client**.
- Phantom Wallet acts as the **MWA compliant wallet**.
- The two communicate directly on-device over an encrypted **local WebSocket transport** (`ws://localhost:<port>/solana-wallet`), initiated by an Android intent (`solana-wallet://`).

```
┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
│       StudyChain (Flutter)      │                 │         Phantom Mobile          │
│                                 │                 │                                 │
│  1. LocalAssociationScenario    │                 │                                 │
│     Creates local WS server     │                 │                                 │
│                                 │                 │                                 │
│  2. Broadcast Intent            │  solana-wallet: │  3. Phantom catches Intent,     │
│     startActivityForResult(...) ├────────────────►│     connects to local WS        │
│                                 │                 │                                 │
│  4. authorize() / reauthorize() │   MWA Session   │  5. Displays dApp metadata      │
│     Transfers auth_token        │◄───────────────►│     User taps "Connect"         │
│                                 │                 │                                 │
│  6. Pre-flight Simulation (RPC) │                 │                                 │
│     Validates tx before wallet  │                 │                                 │
│                                 │                 │                                 │
│  7. signTransactions()          │  Compiled Tx    │  8. User reviews fee & prompt,  │
│     Sends raw tx bytes          ├────────────────►│     Phantom signs with User Key │
│                                 │                 │                                 │
│  9. addSignature(mintKeypair)   │  Signed Payload │                                 │
│     Injects ephemeral mint sig  │◄────────────────┤                                 │
│                                 │                 │                                 │
│ 10. submitTransaction(RPC)      │                 │                                 │
│     skipPreflight=true          │                 │                                 │
└─────────────────────────────────┘                 └─────────────────────────────────┘
```

---

## ⚙️ Android OS Setup (`AndroidManifest.xml`)

Due to Android 11+ (API 30+) package visibility restrictions, an app cannot discover other installed apps unless they are explicitly declared in the manifest.

Add the `solana-wallet` scheme to the `<queries>` block in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.studychain">

    <!-- MWA Intent Filter: Required for discovering MWA-compatible wallets like Phantom -->
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="solana-wallet" />
        </intent>
    </queries>

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="studychain"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        ...
    </application>
</manifest>
```

---

## 📦 Dependencies (`pubspec.yaml`)

The Flutter project relies on the following core packages:

```yaml
dependencies:
  # Official MWA Client specification implementation for Flutter
  solana_mobile_client: ^0.1.2

  # Core Solana library for Dart (tx compilation, keypairs, RPC)
  solana: ^0.30.4

  # State management
  flutter_riverpod: ^2.4.0

  # Fast, encrypted local key-value storage for wallet session caching
  hive_flutter: ^1.1.0

  # Base58 encoding/decoding for Solana public keys and signatures
  bs58: ^1.0.2

  # HTTP Client for RPC calls
  dio: ^5.3.0
```

---

## 🔑 Session Lifecycle & Authorization Flow

The session lifecycle is implemented in [`lib/services/wallet_service.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/wallet_service.dart).

### 1. Opening an MWA Session (`_openSession`)
Every interaction with Phantom requires establishing a `LocalAssociationScenario`:

```dart
Future<({LocalAssociationScenario session, MobileWalletAdapterClient client})>
    _openSession() async {
  print('[WALLET] Opening MWA session...');
  // 1. Create a local association scenario
  final session = await LocalAssociationScenario.create();

  // 2. Launch the wallet by broadcasting the solana-wallet:// intent
  session.startActivityForResult(null).ignore();

  // 3. Connect to the WebSocket transport and get the MWA client
  final client = await session.start();
  print('[WALLET] Session opened, client started');
  return (session: session, client: client);
}
```

### 2. Connecting the Wallet (`connectWallet`)
When the user connects for the first time, Phantom prompts them to approve the connection:

```dart
Future<WalletConnection?> connectWallet() async {
  final s = await _openSession();
  try {
    final result = await s.client.authorize(
      identityUri: Uri.parse(StudyChainConfig.appUri),
      iconUri: Uri.parse(StudyChainConfig.appIconUri),
      identityName: StudyChainConfig.appName,
      cluster: StudyChainConfig.cluster, // 'devnet' or 'mainnet-beta'
    );

    if (result != null) {
      _authToken = result.authToken;
      _publicKey = result.publicKey;

      // Cache credentials locally in Hive for silent re-authentication
      final box = Hive.box('wallet_auth');
      await box.put('mwa_auth_token', _authToken!);
      await box.put('mwa_public_key', base58.encode(_publicKey!));

      return WalletConnection(
        publicKey: base58.encode(_publicKey!),
        authToken: _authToken,
        isConnected: true,
        connectedAt: DateTime.now(),
      );
    }
  } finally {
    await s.session.close();
  }
  return null;
}
```

### 3. Silent Reauthorization on App Launch (`initializeMWA`)
On subsequent launches, the app automatically reconnects without showing any popup prompts to the user:

```dart
Future<WalletConnection?> initializeMWA() async {
  final box = Hive.box('wallet_auth');
  final cachedToken = box.get('mwa_auth_token') as String?;
  final cachedKey = box.get('mwa_public_key') as String?;

  if (cachedToken == null || cachedKey == null) return null;

  _authToken = cachedToken;
  final s = await _openSession();
  try {
    final ok = await _reauthorizeSession(s.client);
    if (ok) {
      return WalletConnection(
        publicKey: base58.encode(_publicKey!),
        authToken: _authToken,
        isConnected: true,
        connectedAt: DateTime.now(),
      );
    }
  } finally {
    await s.session.close();
  }
  return null;
}
```

### 4. ⚠️ The Independent Session Rule in MWA v2.0
> **CRITICAL RULE**: In the Mobile Wallet Adapter v2.0 specification, **every new `LocalAssociationScenario` session is completely independent**.
> Before performing any privileged action (such as `signTransactions` or `signMessages`), the app **MUST call `reauthorize()`** on that specific session client:

```dart
Future<bool> _reauthorizeSession(MobileWalletAdapterClient client) async {
  if (_authToken == null) return false;
  try {
    final result = await client.reauthorize(
      identityUri: Uri.parse(StudyChainConfig.appUri),
      iconUri: Uri.parse(StudyChainConfig.appIconUri),
      identityName: StudyChainConfig.appName,
      authToken: _authToken!,
    );

    if (result != null) {
      _authToken = result.authToken; // Phantom may rotate tokens
      _publicKey = result.publicKey;

      final box = Hive.box('wallet_auth');
      await box.put('mwa_auth_token', _authToken!);
      await box.put('mwa_public_key', base58.encode(_publicKey!));
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
```
If `_reauthorizeSession()` fails (for example, if the user revoked permissions in Phantom), `wallet_service.dart` automatically falls back to a full `client.authorize()` prompt.

---

## ⚡ The Multi-Signer Problem & Decoupled Signing Solution

### The Challenge: Why `signAndSendTransactions` fails
When minting an NFT plan (`mint_plan`), the transaction requires **two separate signers**:
1. **The Buyer / User Keypair**: Pays for the plan in SOL and pays network fees. This private key resides **only** in Phantom.
2. **The Ephemeral Mint Keypair**: A new Solana keypair generated locally inside Flutter (`result.mintKeypair`) to instantiate the SPL token mint.

Phantom's MWA `signAndSendTransactions` API only knows about the user's private key. It cannot sign for the ephemeral mint keypair! If submitted directly, the transaction will fail on-chain with `SignatureVerificationFailed`.

### The Solution: Decoupled Multi-Party Signing
StudyChain splits transaction signing into separate stages:
1. **Phantom signs** the user's portion of the transaction via `signTransactions`.
2. **Flutter injects** the mint keypair's signature using [`nftService.addSignature()`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/nft_service.dart#L497-L521).
3. **App submits** the fully dual-signed transaction to the RPC node.

#### Step 1: Request Phantom Signature
In [`lib/services/wallet_service.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/wallet_service.dart#L155-L206):
```dart
Future<Uint8List?> signTransaction(Uint8List transactionBytes) async {
  final s = await _openSession();
  try {
    // 1. Reauthorize the session
    final reauthorized = await _reauthorizeSession(s.client);
    if (!reauthorized) {
      await s.client.authorize(...); // Fallback authorize
    }

    // 2. Request signature from Phantom
    final result = await s.client.signTransactions(
      transactions: [transactionBytes],
    );

    if (result.signedPayloads.isNotEmpty) {
      return result.signedPayloads.first;
    }
  } finally {
    await s.session.close();
  }
  return null;
}
```

#### Step 2: Inject Local Signature
In [`lib/services/nft_service.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/nft_service.dart#L497-L521):
```dart
Future<Uint8List> addSignature(
    Uint8List phantomSignedBytes, Ed25519HDKeyPair localKeypair) async {
  // 1. Decode the transaction returned from Phantom
  final tx = SignedTx.fromBytes(phantomSignedBytes);
  final compiled = tx.compiledMessage;

  // 2. Sign the exact compiled message bytes that Phantom signed
  final localSig = await localKeypair.sign(compiled.toByteArray());

  // 3. Reconstruct signatures list and insert local signature at mint index
  final signatures = List<Signature>.from(tx.signatures);
  final idx = compiled.accountKeys.indexWhere((k) => k == localKeypair.publicKey);
  if (idx >= 0 && idx < signatures.length) {
    signatures[idx] = Signature(localSig.bytes, publicKey: localKeypair.publicKey);
  }

  // 4. Return serialized transaction with both signatures intact
  final finalTx = SignedTx(signatures: signatures, compiledMessage: compiled);
  return Uint8List.fromList(finalTx.toByteArray().toList());
}
```

---

## 🚀 Pre-flight Simulation & Blockhash Latency Optimization

### Pre-flight Simulation Before Triggering Phantom
Before opening Phantom, the app simulates the transaction against Helius RPC ([`plans_screen.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/screens/plans_screen.dart#L202)):
```dart
final simError = await solanaService.simulateTransactionBytes(txBytes);
if (simError != null) {
  // Warn user immediately without opening Phantom if balance or constraints fail
  showError('Simulation failed: $simError');
  return;
}
```

### Handling the Phantom UI Prompt Delay (`skipPreflight: true`)
When Phantom opens, users spend 10 to 30 seconds reviewing transaction details, inspecting fees, and entering biometrics/PINs. 

In Solana, recent blockhashes expire after 150 blocks (~60–90 seconds). An RPC preflight check can fail if the blockhash window has aged during user interaction.

Because StudyChain already verified transaction logic during its own pre-flight simulation, it submits to Helius RPC with `skipPreflight: true` ([`lib/services/solana_service.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/solana_service.dart#L459-L466)):

```dart
final response = await _dio.post(
  _rpcUrl,
  data: {
    'jsonrpc': '2.0',
    'id': 'helius-${DateTime.now().millisecondsSinceEpoch}',
    'method': 'sendTransaction',
    'params': [
      txBase64,
      {
        "encoding": "base64",
        "skipPreflight": true,              // Bypass RPC preflight due to Phantom UI latency
        "preflightCommitment": "confirmed",
        "maxRetries": 3,
      }
    ],
  },
);
```

---

## 🛡️ Sign In With Solana (SIWS)

StudyChain uses cryptographic wallet message signing for passwordless content authentication ([`lib/services/wallet_service.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/wallet_service.dart#L212-L250)):

```dart
Future<Map<String, String>?> signInWithSolana({
  required String message,
  required String nonce,
}) async {
  final messageBytes = Uint8List.fromList(message.codeUnits);
  final s = await _openSession();
  try {
    final reauthorized = await _reauthorizeSession(s.client);
    if (!reauthorized) throw Exception('Reauthorization failed');

    // Phantom displays plaintext SIWS message to the user
    final result = await s.client.signMessages(
      messages: [messageBytes],
      addresses: [_publicKey!],
    );

    if (result.signedMessages.isNotEmpty) {
      return {
        'wallet_address': base58.encode(_publicKey!),
        'message': message,
        'signature': base58.encode(result.signedMessages.first.signatures.first),
      };
    }
  } finally {
    await s.session.close();
  }
  return null;
}
```

---

## 🔄 Riverpod State Management

State is bound reactively to Flutter widgets via Riverpod in [`lib/providers/wallet_provider.dart`](file:///d:/Yash/flutter_project/SwapCredit/lib/providers/wallet_provider.dart):

```dart
final walletProvider = StateNotifierProvider<WalletNotifier, WalletConnection?>((ref) {
  final service = ref.watch(walletServiceProvider);
  return WalletNotifier(service);
});

final isWalletConnectedProvider = Provider((ref) {
  final wallet = ref.watch(walletProvider);
  return wallet?.isConnected ?? false;
});

final currentWalletAddressProvider = Provider((ref) {
  return ref.watch(walletProvider)?.publicKey;
});
```

When Phantom connects:
1. `walletProvider` emits the new `WalletConnection`.
2. The UI header automatically updates to show the user's truncated address (e.g. `7bN8...auo4`).
3. [`planCheckerProvider`](file:///d:/Yash/flutter_project/SwapCredit/lib/services/plan_checker.dart) triggers `getOwnerNFTs` via Helius RPC and unlocks notes, quizzes, and mock tests according to the NFT tier held.

---

## 🧪 Step-by-Step Developer Testing Guide on Devnet

### 1. Install Phantom on Android
- Install **Phantom Wallet** on your Android test device or emulator via Google Play Store (or sideload the official APK).

### 2. Configure Phantom for Devnet
1. Open Phantom and create or import a test wallet.
2. Tap the **Settings icon** (gear icon in the bottom right / top left).
3. Scroll down and tap **Developer Settings**.
4. Toggle **Testnet Mode** to **ON**.
5. Tap **Change Network** and select **Devnet**.

### 3. Airdrop Devnet SOL
1. Tap on your wallet address to copy it.
2. Request Devnet SOL via:
   - [Solana Faucet](https://faucet.solana.com)
   - Or CLI: `solana airdrop 2 <YOUR_PHANTOM_ADDRESS> --url devnet`

### 4. Build and Run StudyChain
```bash
# Ensure Android device is detected
flutter devices

# Run on Android device
flutter run -d <device_id>
```

### 5. Verify the Connection & Purchase Flow
1. Tap **"Connect Wallet"** on StudyChain's splash or home screen.
2. Phantom will automatically pop up via the Android intent.
3. Tap **"Connect"** in Phantom.
4. Go to **Plans**, select **Premium Plan (0.3 SOL)**, and tap **"Buy Plan"**.
5. Watch the progression:
   - *Pre-flight RPC simulation passes*.
   - *Phantom opens and prompts for approval*.
   - *User approves in Phantom*.
   - *App injects mint signature and submits transaction*.
   - *Plan NFT minted and content unlocked on-chain!*
