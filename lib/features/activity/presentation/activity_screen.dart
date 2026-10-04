import 'package:flutter/material.dart';

import '../../../core/theme/orion_theme.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.activities, super.key});

  final List<String> activities;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Activity', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        const Text(
          'A timeline of marketplace and account events.',
          style: TextStyle(color: OrionColors.muted),
        ),
        const SizedBox(height: 22),
        for (var index = 0; index < activities.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OrionColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: OrionColors.paleRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _activityIcon(activities[index]),
                    color: OrionColors.oxblood,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activities[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        index == 0
                            ? 'Just now · Preview'
                            : 'Sep ${27 - index}, 2026 · Preview',
                        style: const TextStyle(
                          color: OrionColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: OrionColors.muted,
                  size: 19,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Preview activity is not sourced from Solana transaction history.',
          style: TextStyle(color: OrionColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  IconData _activityIcon(String activity) {
    if (activity.contains('verification')) {
      return Icons.fact_check_outlined;
    }
    if (activity.contains('Wallet')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (activity.contains('redemption')) {
      return Icons.local_shipping_outlined;
    }
    if (activity.contains('listed')) {
      return Icons.sell_outlined;
    }
    return Icons.token_outlined;
  }
}
