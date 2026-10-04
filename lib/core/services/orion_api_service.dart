import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/orion_config.dart';
import '../../features/marketplace/models/asset_listing.dart';
import '../../features/marketplace/data/mock_inventory.dart';
import '../../features/portfolio/models/owned_claim.dart';

class OrionApiService {
  static final http.Client _client = http.Client();
  static String? _workingBaseUrl;

  static Future<String> getBaseUrl() async {
    if (_workingBaseUrl != null) return _workingBaseUrl!;
    for (final candidate in OrionConfig.candidateApiUrls) {
      try {
        final res = await _client
            .get(Uri.parse('$candidate/assets'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          _workingBaseUrl = candidate;
          return candidate;
        }
      } catch (_) {}
    }
    return OrionConfig.apiBaseUrl;
  }

  /// 1. Fetch live marketplace asset listings from the database
  static Future<List<AssetListing>> fetchAssets() async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/assets');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map(
                (item) => AssetListing.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[OrionApiService] fetchAssets error, using fallback catalog: $e',
      );
    }
    // Reliable fallback if backend is unreachable
    return MockInventory.listings;
  }

  /// 1b. Fetch live oracle price history ticks for an individual asset
  static Future<
    ({List<double> points, List<String> times, double changePercentage})?
  >
  fetchAssetPriceHistory(int assetId, {String timeframe = '1D'}) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse(
      '$baseUrl/assets/$assetId/history?timeframe=$timeframe',
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'] as Map<String, dynamic>;
          final rawPoints = data['points'] as List?;
          final rawTimes = data['times'] as List?;
          if (rawPoints != null && rawPoints.isNotEmpty) {
            final points = rawPoints.map((p) => (p as num).toDouble()).toList();
            final times = rawTimes?.map((t) => t.toString()).toList() ?? [];
            final change =
                (data['changePercentage'] as num?)?.toDouble() ?? 0.0;
            return (points: points, times: times, changePercentage: change);
          }
        }
      }
    } catch (e) {
      debugPrint('[OrionApiService] fetchAssetPriceHistory error: $e');
    }
    return null;
  }

  /// 2. Fetch live claims owned by a connected Solana wallet
  static Future<List<OwnedClaim>> fetchUserClaims(String wallet) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/claims/$wallet');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((item) => OwnedClaim.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[OrionApiService] fetchUserClaims error: $e');
    }
    return [];
  }

  /// 3. Fetch portfolio total value and historical points for financial charts
  static Future<Map<String, dynamic>?> fetchPortfolio(
    String wallet, {
    String timeframe = '1D',
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/portfolio/$wallet?timeframe=$timeframe');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[OrionApiService] fetchPortfolio error: $e');
    }
    return null;
  }

  /// 4. Execute and record an on-chain / marketplace purchase
  static Future<Map<String, dynamic>> executePurchase({
    required String buyer,
    required int assetId,
    num amount = 1.0,
    String? txHash,
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/trade/purchase');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'buyer': buyer,
              'assetId': assetId,
              'amount': amount,
              if (txHash != null) 'txHash': txHash,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final decoded = json.decode(response.body);
      if (response.statusCode == 201 && decoded['success'] == true) {
        return decoded['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
          decoded['error'] ?? 'Purchase failed (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('[OrionApiService] executePurchase error: $e');
      rethrow;
    }
  }

  /// 4b. Build unsigned payment transaction for Mobile Wallet Adapter
  static Future<Map<String, dynamic>?> buildPaymentTransaction({
    required String buyer,
    String currency = 'SOL',
    double amount = 0.01,
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/trade/build-payment-tx');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'buyer': buyer,
              'currency': currency,
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = json.decode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        return decoded['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[OrionApiService] buildPaymentTransaction error: $e');
    }
    return null;
  }

  /// 5. Submit physical redemption ticket request
  static Future<int> requestRedemption({
    required int claimId,
    required String redeemer,
    String carrier = "Brink's Secure Logistics",
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/redemptions');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'claimId': claimId,
            'redeemer': redeemer,
            'carrier': carrier,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final decoded = json.decode(response.body);
    if (response.statusCode == 201 && decoded['success'] == true) {
      return (decoded['ticketId'] as num).toInt();
    } else {
      throw Exception(decoded['error'] ?? 'Redemption request failed');
    }
  }

  /// 6. Submit supplier inventory collateral intake proposal
  static Future<int> submitSupplierProposal({
    required String supplier,
    required int assetId,
    required String category,
    required int conditionGrade,
    required int proposedUnits,
    required String auditor,
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/proposals');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'supplier': supplier,
            'assetId': assetId,
            'category': category,
            'conditionGrade': conditionGrade,
            'proposedUnits': proposedUnits,
            'auditor': auditor,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final decoded = json.decode(response.body);
    if (response.statusCode == 201 && decoded['success'] == true) {
      return (decoded['proposalId'] as num).toInt();
    } else {
      throw Exception(decoded['error'] ?? 'Proposal submission failed');
    }
  }
}
