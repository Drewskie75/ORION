import 'package:flutter/material.dart';
import '../../../core/theme/orion_theme.dart';
import '../models/portfolio_data.dart';
import 'widgets/portfolio_chart.dart';

/// Apple-designed Orion Home Screen.
/// Built with Apple Human Interface Guidelines:
/// - SF Pro-grade typographic hierarchy and tracking
/// - Glassmorphism & obsidian depth with specular specular borders
/// - Authentic financial chart with Monotone Spline (no squiggles) and touch scrubbing
/// - Apple Stocks timeframe selector (1D, 1W, 1M, 1Y, ALL)
/// - Control Center-style tactile action squircles
/// - Apple Watchlist-style trending RWA asset items
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSummary,
    this.walletAddress,
    this.onExploreTap,
    this.onWatchlistTap,
    this.onPortfolioTap,
    this.onMoreTap,
    this.onSeeAllTrendingTap,
    this.onAssetTap,
    this.onProfileTap,
    this.onSearchTap,
  });

  final PortfolioSummary? initialSummary;
  final String? walletAddress;
  final VoidCallback? onExploreTap;
  final VoidCallback? onWatchlistTap;
  final VoidCallback? onPortfolioTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onSeeAllTrendingTap;
  final ValueChanged<TrendingAssetItem>? onAssetTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSearchTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PortfolioSummary _summary;
  late List<TrendingAssetItem> _trendingAssets;
  PortfolioTimeframe _selectedTimeframe = PortfolioTimeframe.oneDay;

  // Active scrubbed price when user drags across the chart
  double? _scrubbedPrice;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary ??
        const PortfolioSummary(
          totalValue: 0.0,
          changePercentage: 0.0,
          changeAmount: 0.0,
          isPositive: true,
          timeframe: PortfolioTimeframe.oneDay,
          historyPoints: [0.0, 0.0],
        );
    _trendingAssets = PortfolioRepository.getTrendingAssets();
    _loadTimeframeData(_selectedTimeframe);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSummary != oldWidget.initialSummary && widget.initialSummary != null) {
      setState(() => _summary = widget.initialSummary!);
    }
    _loadTimeframeData(_selectedTimeframe);
  }

  Future<void> _loadTimeframeData(PortfolioTimeframe tf) async {
    setState(() => _selectedTimeframe = tf);
    try {
      final summary = await PortfolioRepository.fetchPortfolioSummary(
        timeframe: tf,
        walletAddress: widget.walletAddress,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _scrubbedPrice = null;
        });
      }
    } catch (_) {}
  }

  String _formatCurrency(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '\$ $intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = _scrubbedPrice != null
        ? _formatCurrency(_scrubbedPrice!)
        : _summary.formattedValue;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: RefreshIndicator(
        onRefresh: () => _loadTimeframeData(_selectedTimeframe),
        color: OrionColors.red,
        backgroundColor: const Color(0xFF1C1C1E),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // 1. Apple-style Header: Greeting & Trader Profile
            _buildAppleHeader(),

            const SizedBox(height: 22),

            // 2. Apple Wallet/Stocks-style Portfolio Card with Monotone Chart
            _buildApplePortfolioCard(displayValue),

            const SizedBox(height: 24),

            // 3. Apple Control Center-style Quick Actions
            _buildAppleQuickActions(),

            const SizedBox(height: 28),

            // 4. Apple Watchlist-style Trending Assets Header
            _buildTrendingHeader(),

            const SizedBox(height: 12),

            // 5. Trending Assets List with Monotone Sparklines
            ..._trendingAssets.map((asset) => _buildTrendingAssetTile(asset)),

            const SizedBox(height: 20),

            // Powered by Orion Protocol Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/orion_icon.jpg',
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Powered by Orion Protocol · Solana Devnet',
                  style: TextStyle(
                    color: OrionColors.muted,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Top Greeting & Profile Header with Apple typography and tactile buttons
  Widget _buildAppleHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Orion Brand Icon Squircle
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OrionColors.oxblood, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: OrionColors.crimson.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/images/orion_icon.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Greeting & Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning,',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'Trader',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // Apple-style Frosted Search Button
        GestureDetector(
          onTap: widget.onSearchTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.88),
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Apple-style Profile Avatar with warm amber rim
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFD49B6A), Color(0xFF9E6316)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD49B6A).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.6),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Apple-style Portfolio Card with Monotone Chart, Timeframe Selector, and Touch Scrubbing
  Widget _buildApplePortfolioCard(String displayValue) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: OrionColors.red.withValues(alpha: 0.12),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top Section: Metrics + Chart Area in clean side-by-side Row (NO OVERLAP)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 10),
              child: SizedBox(
                height: 124,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left Side: Metrics (Total Portfolio Value, Large Amount, Green Pill)
                    Expanded(
                      flex: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title
                          Text(
                            _scrubbedPrice != null
                                ? 'Scrubbed Value'
                                : 'Total Portfolio Value',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.60),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),

                          // Large Currency Display (Fitted to never collide)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayValue,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),

                          // Apple-style Green Change Capsule
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_drop_up_rounded,
                                  color: Color(0xFF30D158),
                                  size: 18,
                                ),
                                Text(
                                  _summary.formattedChange,
                                  style: const TextStyle(
                                    color: Color(0xFF30D158),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Right Side: Dedicated Chart (starts strictly after text, zero overlap)
                    Expanded(
                      flex: 48,
                      child: SizedBox(
                        height: 112,
                        child: PortfolioAreaChart(
                          points: _summary.historyPoints,
                          lineColor: OrionColors.red,
                          height: 112,
                          onScrub: (scrubVal) {
                            setState(() => _scrubbedPrice = scrubVal);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider Hairline
            Divider(
              height: 1,
              thickness: 0.8,
              color: Colors.white.withValues(alpha: 0.06),
            ),

            // Timeframe Selector Row (1D, 1W, 1M, 1Y, ALL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: PortfolioTimeframe.values.map((tf) {
                  final isSelected = tf == _selectedTimeframe;
                  return GestureDetector(
                    onTap: () => _loadTimeframeData(tf),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.8,
                              )
                            : null,
                      ),
                      child: Text(
                        tf.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.50),
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Apple Control Center-style Quick Actions with tactile feedback
  Widget _buildAppleQuickActions() {
    final actions = [
      (
        label: 'Explore',
        icon: Icons.explore_rounded,
        onTap: widget.onExploreTap,
      ),
      (
        label: 'Watchlist',
        icon: Icons.bookmark_rounded,
        onTap: widget.onWatchlistTap,
      ),
      (
        label: 'Portfolio',
        icon: Icons.wallet_rounded,
        onTap: widget.onPortfolioTap,
      ),
      (
        label: 'More',
        icon: Icons.more_horiz_rounded,
        onTap: widget.onMoreTap,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return GestureDetector(
          onTap: item.onTap,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF161619),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white.withValues(alpha: 0.90),
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Apple-style Trending Assets Header
  Widget _buildTrendingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Trending Assets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          onTap: widget.onSeeAllTrendingTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: OrionColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    color: OrionColors.red,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: OrionColors.red,
                  size: 10,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Apple Watchlist-style Asset Row
  Widget _buildTrendingAssetTile(TrendingAssetItem asset) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onAssetTap?.call(asset),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                // Asset Icon Squircle
                _buildAssetIcon(asset),

                const SizedBox(width: 14),

                // Name & Metadata Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        asset.symbol,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Monotone Mini Sparkline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: MiniSparkline(
                    points: asset.sparklinePoints,
                    lineColor: OrionColors.red,
                    width: 56,
                    height: 24,
                  ),
                ),

                // Price and Percentage Capsule
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      asset.formattedPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        asset.formattedChange,
                        style: const TextStyle(
                          color: Color(0xFF30D158),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Apple-style Squircle icon container
  Widget _buildAssetIcon(TrendingAssetItem asset) {
    switch (asset.iconType) {
      case TrendingIconType.apple:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF222226),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.phone_iphone_rounded,
            color: Colors.white,
            size: 22,
          ),
        );
      case TrendingIconType.nvidia:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2E461A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.memory_rounded,
            color: Colors.white,
            size: 22,
          ),
        );
      case TrendingIconType.gold:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6B450E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: Colors.white,
            size: 20,
          ),
        );
      case TrendingIconType.tesla:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF5E1313),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.electric_car_rounded,
            color: Colors.white,
            size: 20,
          ),
        );
      case TrendingIconType.customImage:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: asset.customImagePath != null
                ? DecorationImage(
                    image: AssetImage(asset.customImagePath!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        );
    }
  }
}
