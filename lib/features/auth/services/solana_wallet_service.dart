import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/orion_api_service.dart';

class SolanaConnectionResult {
  SolanaConnectionResult({
    required this.publicKey,
    required this.walletName,
    this.authToken,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  final String publicKey;
  final String walletName;
  final String? authToken;
  final DateTime connectedAt;

  /// Check whether the 30-day session has expired
  bool get isExpired {
    return DateTime.now().difference(connectedAt).inDays >=
        SolanaWalletService.sessionDurationDays;
  }

  /// Number of days remaining before session expires
  int get daysRemaining {
    final diff =
        SolanaWalletService.sessionDurationDays -
        DateTime.now().difference(connectedAt).inDays;
    return diff > 0 ? diff : 0;
  }

  String get shortenedAddress {
    if (publicKey.length <= 10) return publicKey;
    return '${publicKey.substring(0, 4)}...${publicKey.substring(publicKey.length - 4)}';
  }
}

class SolanaWalletService {
  static const String _dappName = 'Orion';
  static final Uri _identityUri = Uri.parse('https://orionmarketplace.io');
  static final Uri _iconUri = Uri.parse('favicon.ico');

  /// Session duration: 30 days
  static const int sessionDurationDays = 30;

  // Storage keys for persisting session across app launches
  static const String _keyPublicKey = 'orion_wallet_pubkey';
  static const String _keyWalletName = 'orion_wallet_name';
  static const String _keyAuthToken = 'orion_wallet_auth_token';
  static const String _keyConnectedAt = 'orion_wallet_connected_at';
  static final http.Client _rpcClient = http.Client();

  /// Cluster used across development: Solana Devnet
  static const String cluster = 'devnet';
  static const String rpcUrl = 'https://api.devnet.solana.com';

  static Future<
    ({LocalAssociationScenario session, MobileWalletAdapterClient client})
  >
  _openSession() async {
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    final client = await session.start();
    return (session: session, client: client);
  }

  static Future<String> _broadcastSignedTransaction(
    Uint8List transaction,
  ) async {
    final response = await _rpcClient
        .post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'sendTransaction',
            'params': [
              base64Encode(transaction),
              {
                'encoding': 'base64',
                'skipPreflight': true,
                'preflightCommitment': 'confirmed',
                'maxRetries': 3,
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Solana RPC rejected the signed transaction.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      final error = decoded['error'];
      throw Exception(
        error is Map ? error['message']?.toString() : error.toString(),
      );
    }
    final signature = decoded['result'];
    if (signature is! String || signature.isEmpty) {
      throw Exception('Solana RPC did not return a transaction signature.');
    }
    return signature;
  }

  /// Encode raw bytes to standard Solana Base58 address string
  static String encodeBase58(List<int> bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    if (bytes.isEmpty) return '';

    var zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }

    BigInt intVal = BigInt.zero;
    for (final byte in bytes) {
      intVal = (intVal << 8) | BigInt.from(byte);
    }

    final buffer = StringBuffer();
    while (intVal > BigInt.zero) {
      final remainder = (intVal % BigInt.from(58)).toInt();
      intVal = intVal ~/ BigInt.from(58);
      buffer.write(alphabet[remainder]);
    }

    final encoded = buffer.toString().split('').reversed.join('');
    return ('1' * zeros) + encoded;
  }

  /// Save wallet session to persistent local storage for 30 days
  static Future<void> saveSession(SolanaConnectionResult connection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPublicKey, connection.publicKey);
      await prefs.setString(_keyWalletName, connection.walletName);
      if (connection.authToken != null) {
        await prefs.setString(_keyAuthToken, connection.authToken!);
      } else {
        await prefs.remove(_keyAuthToken);
      }
      await prefs.setInt(
        _keyConnectedAt,
        connection.connectedAt.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to save wallet session: $e');
    }
  }

  /// Retrieve the saved wallet session. Returns null if none exists or if
  /// the 30-day window has expired.
  static Future<SolanaConnectionResult?> getPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final publicKey = prefs.getString(_keyPublicKey);
      final walletName = prefs.getString(_keyWalletName);
      final authToken = prefs.getString(_keyAuthToken);
      final connectedAtMs = prefs.getInt(_keyConnectedAt);

      if (publicKey == null || walletName == null || connectedAtMs == null) {
        return null;
      }

      final connectedAt = DateTime.fromMillisecondsSinceEpoch(connectedAtMs);
      final session = SolanaConnectionResult(
        publicKey: publicKey,
        walletName: walletName,
        authToken: authToken,
        connectedAt: connectedAt,
      );

      // Verify 30-day validity window
      if (session.isExpired) {
        await clearSession();
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('Failed to read persisted wallet session: $e');
      return null;
    }
  }

  /// Clear the persisted wallet session (e.g. on manual user disconnect or expiry)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPublicKey);
      await prefs.remove(_keyWalletName);
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyConnectedAt);
    } catch (e) {
      debugPrint('Failed to clear wallet session: $e');
    }
  }

  /// Connect using the official Solana Mobile Wallet Adapter (MWA).
  ///
  /// This triggers the native Android system wallet picker, presenting all
  /// installed Solana wallets (Seed Vault, Jupiter, Phantom, Solflare, etc.).
  /// Successfully connected sessions are saved for 30 days.
  static Future<SolanaConnectionResult?> connectNativeWallet({
    void Function(String message)? onStatus,
  }) async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (!isAndroid) {
      onStatus?.call('Connected preview wallet (Desktop/Testing)');
      final previewConnection = SolanaConnectionResult(
        publicKey: '8fQpWqT7xL5hNzKaYmX9P3RvUsJ1eM6tDbC4s',
        walletName: 'Solana Mobile Wallet',
        authToken: 'preview-token',
      );
      await saveSession(previewConnection);
      return previewConnection;
    }

    try {
      onStatus?.call('Connecting to wallet...');
      final opened = await _openSession();
      try {
        onStatus?.call('Waiting for Phantom authorization...');
        final result = await opened.client.authorize(
          identityUri: _identityUri,
          iconUri: _iconUri,
          identityName: _dappName,
          cluster: cluster,
        );
        if (result == null) {
          throw Exception('Phantom authorization was cancelled or declined.');
        }

        final connection = SolanaConnectionResult(
          publicKey: encodeBase58(result.publicKey),
          walletName: result.walletUriBase?.host.isNotEmpty == true
              ? result.walletUriBase!.host
              : (result.accountLabel ?? 'Phantom'),
          authToken: result.authToken,
        );
        await saveSession(connection);
        return connection;
      } finally {
        await opened.session.close();
      }
    } catch (e) {
      debugPrint('Native Solana MWA error: $e');
      rethrow;
    }
  }

  /// Request Phantom approval, return to Orion, and broadcast the signed transaction.
  static Future<String?> requestWalletTransactionApproval({
    required String buyerWallet,
    required String currency,
    required double paymentAmount,
    void Function(String status)? onStatus,
  }) async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      onStatus?.call('Desktop/Preview mode: Approving transaction...');
      return null;
    }

    try {
      onStatus?.call('Opening wallet to authorize $currency payment...');
      final opened = await _openSession();
      try {
        final savedSession = await getPersistedSession();
        AuthorizationResult? authorization;
        if (savedSession?.authToken != null) {
          onStatus?.call('Reauthorizing Phantom session...');
          authorization = await opened.client.reauthorize(
            identityUri: _identityUri,
            iconUri: _iconUri,
            identityName: _dappName,
            authToken: savedSession!.authToken!,
          );
        }
        authorization ??= await opened.client.authorize(
          identityUri: _identityUri,
          iconUri: _iconUri,
          identityName: _dappName,
          cluster: cluster,
        );
        if (authorization == null) {
          throw Exception('Phantom authorization was cancelled or declined.');
        }

        final authorizedWallet = encodeBase58(authorization.publicKey);
        if (authorizedWallet != buyerWallet) {
          throw Exception(
            'The authorized wallet does not match the purchase wallet. Reconnect the intended account and try again.',
          );
        }
        await saveSession(
          SolanaConnectionResult(
            publicKey: authorizedWallet,
            walletName: authorization.walletUriBase?.host.isNotEmpty == true
                ? authorization.walletUriBase!.host
                : (authorization.accountLabel ?? 'Phantom'),
            authToken: authorization.authToken,
            connectedAt: savedSession?.connectedAt,
          ),
        );

        onStatus?.call('Constructing $currency transaction...');
        final txData = await OrionApiService.buildPaymentTransaction(
          buyer: buyerWallet,
          currency: currency,
          amount: paymentAmount,
        );

        final transactionBase64 = txData?['transactionBase64'];
        if (transactionBase64 is! String || transactionBase64.isEmpty) {
          throw Exception(
            'Could not build the payment transaction. No funds were sent.',
          );
        }

        onStatus?.call('Confirming payment in Phantom...');
        final result = await opened.client.signTransactions(
          transactions: [base64Decode(transactionBase64)],
        );
        if (result.signedPayloads.isEmpty) {
          throw Exception('Phantom cancelled or declined the transaction.');
        }

        onStatus?.call('Broadcasting signed transaction to Solana Devnet...');
        return await _broadcastSignedTransaction(result.signedPayloads.first);
      } finally {
        await opened.session.close();
      }
    } catch (e) {
      debugPrint('[SolanaWalletService] MWA transaction signing error: $e');
      rethrow;
    }
  }

  /// Launch Google Play to install Phantom or Solflare if no wallet is found
  static Future<void> openWalletInstallPage() async {
    final playStoreUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=app.phantom',
    );
    if (await canLaunchUrl(playStoreUri)) {
      await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
    }
  }
}
