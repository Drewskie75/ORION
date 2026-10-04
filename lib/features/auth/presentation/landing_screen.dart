import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/orion_theme.dart';
import '../../marketplace/presentation/marketplace_shell.dart';
import '../services/solana_wallet_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _bgIndex = 0;
  bool _isConnecting = false;
  Timer? _carouselTimer;

  static const List<String> _backgroundImages = [
    'assets/images/land_page.jpg',
    'assets/images/land_2.png',
    'assets/images/land_3.png',
  ];

  final List<({String title, String subtitle})> _slides = const [
    (
      title: 'Real World Assets\nNow in Your Hands',
      subtitle:
          'Trade tokenized real assets like phones, GPUs, RAM and more. Built on blockchain. Powered by you.',
    ),
    (
      title: 'Fractional GPUs &\nAI Compute Nodes',
      subtitle:
          'Own fractions of enterprise H100 clusters and datacenters. Earn active rental yields while hardware appreciates.',
    ),
    (
      title: 'Exotic Supercars &\nCollector Tech',
      subtitle:
          'Invest in high-value physical assets with verifiable custody, instant on-chain settlement, and secondary liquidity.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkExistingSession();
  }

  /// Automatically restore connection if an active session exists (< 30 days old)
  Future<void> _checkExistingSession() async {
    final session = await SolanaWalletService.getPersistedSession();
    if (session != null && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MarketplaceShell(
            initialWalletConnected: true,
            connectedWalletAddress: session.publicKey,
            connectedWalletName: session.walletName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache all 3 background images so cross-fading is instant and buttery smooth
    for (final path in _backgroundImages) {
      precacheImage(AssetImage(path), context);
    }
  }

  void _startTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final nextIndex = (_bgIndex + 1) % _backgroundImages.length;
      setState(() {
        _bgIndex = nextIndex;
        _currentPage = nextIndex;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _goToPage(int page) {
    setState(() {
      _bgIndex = page;
      _currentPage = page;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
    _startTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectWallet() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final connection = await SolanaWalletService.connectNativeWallet(
        onStatus: (status) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: OrionColors.darkRed,
              content: Text(
                status,
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );

      if (connection != null && mounted) {
        // Confirmation snackbar styled with ORION_COLOR palette
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: OrionColors.darkRed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: OrionColors.red, width: 1.2),
            ),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: OrionColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${connection.walletName} Connected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Address: ${connection.shortenedAddress}',
                        style: const TextStyle(
                          color: OrionColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate directly to Marketplace Shell (Homepage)
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MarketplaceShell(
                  initialWalletConnected: true,
                  connectedWalletAddress: connection.publicKey,
                  connectedWalletName: connection.walletName,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 450),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();

        // Classify the error for user-friendly messaging
        String message;
        bool showInstallAction = false;

        if (errorStr.contains('No MWA-compatible wallet') ||
            errorStr.contains('ActivityNotFound')) {
          message =
              'No compatible Solana wallet installed.\nInstall Phantom, Jupiter, or Solflare to continue.';
          showInstallAction = true;
        } else if (errorStr.contains('cancelled') ||
            errorStr.contains('User canceled') ||
            errorStr.contains('declined')) {
          message =
              'Wallet connection was cancelled. Tap Connect to try again.';
        } else if (errorStr.contains('timed out')) {
          message =
              'Wallet connection timed out. Ensure your wallet app is open and try again.';
        } else if (errorStr.contains('channel-error')) {
          message =
              'Communication error with wallet. Please restart the wallet app and try again.';
        } else {
          message =
              'Wallet error: ${errorStr.replaceAll('Exception: ', '')}';
          showInstallAction = true;
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: OrionColors.darkRed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: OrionColors.oxblood,
                width: 1.2,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            action: showInstallAction
                ? SnackBarAction(
                    label: 'Install Wallet',
                    textColor: OrionColors.red,
                    onPressed: SolanaWalletService.openWalletInstallPage,
                  )
                : null,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _handleExploreAsGuest() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MarketplaceShell(initialWalletConnected: false),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: OrionColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Multi-Layer Animated Background (Smooth 1.4s Cross-fade + 3.5s Ken Burns Scale)
          ...List.generate(_backgroundImages.length, (index) {
            final isVisible = _bgIndex == index;
            return Positioned.fill(
              child: AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOutCubic,
                child: AnimatedScale(
                  scale: isVisible ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 3500),
                  curve: Curves.easeOutCubic,
                  child: Image.asset(
                    _backgroundImages[index],
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: OrionColors.surfaceGradient,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }),

          // Atmospheric gradient overlay using ORION_COLOR palette
          const DecoratedBox(
            decoration: BoxDecoration(gradient: OrionColors.atmosphericOverlay),
          ),

          // Edge border subtle neon accent using OrionColors.crimson
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: OrionColors.crimson.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // Main Interactive Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar with Orion Branding Text Only
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Center(
                    child: Text(
                      'ORION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.5,
                        shadows: [
                          Shadow(
                            color: OrionColors.red.withValues(alpha: 0.6),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Carousel Slides Area
                SizedBox(
                  height: screenHeight * 0.28,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                        _bgIndex = index;
                      });
                      _startTimer();
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Headline
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Subtitle
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                height: 1.45,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Carousel Indicator Dots using ORION_COLOR palette (Tap to jump)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final isActive = index == _currentPage;
                    return GestureDetector(
                      onTap: () => _goToPage(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? OrionColors.red
                              : OrionColors.oxblood.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: OrionColors.red.withValues(
                                      alpha: 0.7,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // Primary CTA: Connect Wallet using ORION_COLOR palette & direct native MWA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: OrionColors.buttonGradient,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color.fromARGB(
                          255,
                          102,
                          21,
                          21,
                        ).withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(
                            255,
                            110,
                            24,
                            24,
                          ).withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isConnecting ? null : _handleConnectWallet,
                        borderRadius: BorderRadius.circular(28),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isConnecting) ...[
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Opening Wallet...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: OrionColors.darkRed.withValues(
                                    alpha: 0.6,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Connect Wallet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Secondary CTA: Explore as Guest
                TextButton(
                  onPressed: _handleExploreAsGuest,
                  style: TextButton.styleFrom(
                    foregroundColor: OrionColors.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Explore Marketplace as Guest',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
