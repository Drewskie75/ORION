import 'package:flutter/material.dart';
import '../../../core/theme/orion_theme.dart';
import '../../home/presentation/widgets/portfolio_chart.dart';
import '../models/asset_listing.dart';

/// Markets Tab Screen matching the exact reference screenshot:
/// - "Markets" bold header
/// - "Search assets..." rounded input bar
/// - Horizontal category filter pills (All, RWA, GPU, Gold, Phones, Cars, RAM)
/// - Clean asset listing rows with icon squircles, prices, mini sparklines, and 24h percentage
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    required this.listings,
    required this.walletConnected,
    required this.onConnectWallet,
    required this.onListingSelected,
    super.key,
  });

  final List<AssetListing> listings;
  final bool walletConnected;
  final VoidCallback onConnectWallet;
  final ValueChanged<AssetListing> onListingSelected;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'RWA',
    'GPU',
    'Gold',
    'Phones',
    'Cars',
    'RAM',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssetListing> get _filteredListings {
    return widget.listings.where((item) {
      // Category filter
      final matchesCategory = _selectedCategory == 'All' ||
          _selectedCategory == 'RWA' || // All items are RWAs
          item.category.toLowerCase() == _selectedCategory.toLowerCase() ||
          (_selectedCategory == 'Gold' &&
              (item.name.contains('Gold') || item.name.contains('Silver'))) ||
          (_selectedCategory == 'Phones' &&
              (item.category == 'Phones' || item.category == 'iPhone'));

      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.specification.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visibleItems = _filteredListings;

    return Scaffold(
      backgroundColor: OrionColors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Markets Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: const Text(
                'Markets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),

            // 2. Rounded Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF161619),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  cursorColor: OrionColors.red,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hintText: 'Search assets...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withValues(alpha: 0.45),
                              size: 18,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. Horizontal Category Filter Pills
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? OrionColors.red
                            : const Color(0xFF161619),
                        borderRadius: BorderRadius.circular(18),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 0.8,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      OrionColors.red.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.70),
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 4. Asset Listings List
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Text(
                        'No assets found matching "$_searchQuery"',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return _buildMarketAssetRow(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single Asset Row strictly matching reference screenshot
  Widget _buildMarketAssetRow(AssetListing item) {
    // Extract numeric change value or use default
    final changeText = item.change;
    final isPositive = !changeText.startsWith('-');
    final sparkline = item.sparklinePoints ??
        [10.0, 12.0, 11.0, 14.0, 16.0, 15.0, 18.0, 20.0];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onListingSelected(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                // Icon Squircle Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.iconBgColor ?? const Color(0xFF222226),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 14),

                // Name & Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '\$${item.price}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Red Glowing Mini Sparkline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: MiniSparkline(
                    points: sparkline,
                    lineColor: OrionColors.red,
                    width: 58,
                    height: 24,
                  ),
                ),

                // 24h Percentage
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: isPositive
                          ? const Color(0xFF30D158)
                          : OrionColors.red,
                      size: 18,
                    ),
                    Text(
                      changeText,
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF30D158)
                            : OrionColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
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
}
