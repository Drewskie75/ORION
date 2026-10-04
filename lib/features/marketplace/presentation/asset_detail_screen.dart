import 'package:flutter/material.dart';
import '../../../core/services/orion_api_service.dart';
import '../../../core/theme/orion_theme.dart';
import '../models/asset_listing.dart';
import 'widgets/asset_financial_chart.dart';

/// Asset Detail & Buy Screen matching the exact reference screenshot:
/// - Top bar with Back Arrow & Favorite Star
/// - Asset title ("NVIDIA GPU")
/// - Badges: [RWA] [Tokenized]
/// - Price ($742.18) & Change (▲ 3.76% (24h))
/// - Spotlight Hero Image Card with red ambient backlight
/// - Timeframe selector pills (1D, 1W, 1M, 3M, 1Y, ALL)
/// - Financial Chart with X & Y axes and interactive touch scrubbing
/// - Token Metrics: Market Cap, Volume (24h), Total Supply, Liquidity
/// - Bottom glowing red "Trade" button
class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    required this.listing,
    required this.walletConnected,
    required this.onTrade,
    super.key,
  });

  final AssetListing listing;
  final bool walletConnected;
  final VoidCallback onTrade;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  bool _isFavorite = false;
  String _selectedTimeframe = '1D';
  double? _scrubbedPrice;
  final Map<String, ({List<double> points, List<String> times})> _liveHistoryCache = {};

  static const List<String> _timeframes = ['1D', '1W', '1M', '3M', '1Y', 'ALL'];

  @override
  void initState() {
    super.initState();
    _fetchLiveHistory('1D');
  }

  Future<void> _fetchLiveHistory(String timeframe) async {
    final live = await OrionApiService.fetchAssetPriceHistory(
      widget.listing.assetId,
      timeframe: timeframe,
    );
    if (live != null && live.points.isNotEmpty && mounted) {
      setState(() {
        _liveHistoryCache[timeframe] = (points: live.points, times: live.times);
      });
    }
  }

  /// Generate realistic timeframe data points based on base price or live oracle ticks
  Map<String, ({List<double> points, List<String> times})> get _timeframeDatasets {
    if (_liveHistoryCache.containsKey(_selectedTimeframe)) {
      return {
        _selectedTimeframe: _liveHistoryCache[_selectedTimeframe]!,
      };
    }

    final basePrice = double.tryParse(widget.listing.price.replaceAll(',', '')) ?? 742.18;

    return {
      '1D': (
        points: widget.listing.sparklinePoints != null &&
                widget.listing.sparklinePoints!.length >= 4
            ? [
                basePrice * 0.94,
                basePrice * 0.955,
                basePrice * 0.938,
                basePrice * 0.965,
                basePrice * 0.952,
                basePrice * 0.978,
                basePrice * 0.970,
                basePrice * 0.988,
                basePrice * 0.982,
                basePrice * 0.995,
                basePrice,
              ]
            : [
                basePrice * 0.94,
                basePrice * 0.95,
                basePrice * 0.93,
                basePrice * 0.97,
                basePrice * 0.96,
                basePrice * 0.99,
                basePrice,
              ],
        times: ['00:00', '06:00', '12:00', '18:00', '24:00'],
      ),
      '1W': (
        points: [
          basePrice * 0.91,
          basePrice * 0.925,
          basePrice * 0.92,
          basePrice * 0.945,
          basePrice * 0.96,
          basePrice * 0.95,
          basePrice * 0.98,
          basePrice,
        ],
        times: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
      '1M': (
        points: [
          basePrice * 0.84,
          basePrice * 0.86,
          basePrice * 0.89,
          basePrice * 0.87,
          basePrice * 0.92,
          basePrice * 0.95,
          basePrice * 0.93,
          basePrice * 0.98,
          basePrice,
        ],
        times: ['W1', 'W2', 'W3', 'W4'],
      ),
      '3M': (
        points: [
          basePrice * 0.76,
          basePrice * 0.79,
          basePrice * 0.82,
          basePrice * 0.80,
          basePrice * 0.86,
          basePrice * 0.91,
          basePrice * 0.94,
          basePrice,
        ],
        times: ['Jul', 'Aug', 'Sep'],
      ),
      '1Y': (
        points: [
          basePrice * 0.58,
          basePrice * 0.64,
          basePrice * 0.69,
          basePrice * 0.75,
          basePrice * 0.82,
          basePrice * 0.89,
          basePrice * 0.94,
          basePrice,
        ],
        times: ['Q1', 'Q2', 'Q3', 'Q4'],
      ),
      'ALL': (
        points: [
          basePrice * 0.35,
          basePrice * 0.44,
          basePrice * 0.56,
          basePrice * 0.68,
          basePrice * 0.82,
          basePrice,
        ],
        times: ['2023', '2024', '2025', '2026'],
      ),
    };
  }

  String _formatCurrency(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '\$$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final currentDataset = _timeframeDatasets[_selectedTimeframe] ??
        _timeframeDatasets['1D']!;

    final displayPrice = _scrubbedPrice != null
        ? _formatCurrency(_scrubbedPrice!)
        : '\$${widget.listing.price}';

    return Scaffold(
      backgroundColor: OrionColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavorite ? const Color(0xFFE5A93C) : Colors.white70,
              size: 24,
            ),
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: OrionColors.darkRed,
                  content: Text(
                    _isFavorite
                        ? 'Added ${widget.listing.name} to Watchlist'
                        : 'Removed from Watchlist',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // 1. Asset Title
                Text(
                  widget.listing.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // 2. Badges: [RWA] [Tokenized]
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF260808),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF590202),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'RWA',
                        style: TextStyle(
                          color: Color(0xFFFF5252),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Tokenized',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Price & Change Display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      displayPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_drop_up_rounded,
                          color: Color(0xFF30D158),
                          size: 18,
                        ),
                        Text(
                          '${widget.listing.change} (24h)',
                          style: const TextStyle(
                            color: Color(0xFF30D158),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Hero Spotlight Image Card
                _buildSpotlightCard(),

                const SizedBox(height: 22),

                // 5. Timeframe Selector Pills (1D, 1W, 1M, 3M, 1Y, ALL)
                _buildTimeframeRow(),

                const SizedBox(height: 20),

                // 6. Detailed Financial Chart with X & Y Axes
                AssetFinancialChart(
                  points: currentDataset.points,
                  timeLabels: currentDataset.times,
                  lineColor: OrionColors.red,
                  height: 195,
                  onScrub: (scrubVal) {
                    setState(() => _scrubbedPrice = scrubVal);
                  },
                ),

                const SizedBox(height: 28),

                // 7. Token Metrics Table
                _buildMetricsSection(),

                const SizedBox(height: 12),
              ],
            ),
          ),

          // 8. Bottom Sticky "Trade" CTA Button
          _buildBottomTradeButton(),
        ],
      ),
    );
  }

  /// Spotlight Card with red ambient radial backlight
  Widget _buildSpotlightCard() {
    return Container(
      height: 195,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF100303),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: OrionColors.oxblood.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: OrionColors.red.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Radial Red Glow behind the physical asset
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.1),
                    radius: 0.85,
                    colors: [
                      const Color(0xFF590202).withValues(alpha: 0.85),
                      const Color(0xFF260101).withValues(alpha: 0.70),
                      const Color(0xFF0F0202),
                    ],
                  ),
                ),
              ),
            ),

            // Physical Asset Image
            Padding(
              padding: const EdgeInsets.all(22),
              child: widget.listing.imageAsset != null
                  ? Image.asset(
                      widget.listing.imageAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackIcon(),
                    )
                  : _buildFallbackIcon(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: widget.listing.iconBgColor ?? OrionColors.darkRed,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: OrionColors.red.withValues(alpha: 0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Icon(
        widget.listing.icon,
        color: Colors.white,
        size: 46,
      ),
    );
  }

  /// Timeframe Selector (1D, 1W, 1M, 3M, 1Y, ALL)
  Widget _buildTimeframeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _timeframes.map((tf) {
        final isSelected = tf == _selectedTimeframe;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeframe = tf;
              _scrubbedPrice = null;
            });
            _fetchLiveHistory(tf);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? OrionColors.red : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: OrionColors.red.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              tf,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.50),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Token Metrics (Market Cap, Volume, Supply, Liquidity)
  Widget _buildMetricsSection() {
    final metrics = [
      ('Market Cap', _formatMetric(widget.listing.marketCap, fallback: '\$7.2M', isCurrency: true)),
      ('Volume (24h)', _formatMetric(widget.listing.volume24h, fallback: '\$2.9M', isCurrency: true)),
      ('Total Supply', _formatMetric(widget.listing.totalSupply, fallback: '10,000', isCurrency: false)),
      ('Liquidity', _formatMetric(widget.listing.liquidity, fallback: '\$9.8M', isCurrency: true)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: metrics.map((m) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  m.$1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  m.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatMetric(String? raw, {required String fallback, required bool isCurrency}) {
    if (raw == null || raw.isEmpty) return fallback;
    final clean = raw.replaceAll(r'$', '').replaceAll(',', '').trim();
    final val = double.tryParse(clean);
    if (val == null) return raw;
    final prefix = isCurrency ? '\$' : '';
    if (val >= 1000000) return '$prefix${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '$prefix${(val / 1000).toStringAsFixed(1)}K';
    return isCurrency ? '$prefix${val.toStringAsFixed(2)}' : val.toStringAsFixed(0);
  }

  /// Full-width glowing Trade CTA Button
  Widget _buildBottomTradeButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: OrionColors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: OrionColors.red,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: OrionColors.red.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: widget.onTrade,
              child: const Center(
                child: Text(
                  'Trade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
