import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/marefat_theme.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    super.key,
    required this.todayMinutes,
    required this.goalMinutes,
    required this.streak,
    required this.onTap,
  });

  final int todayMinutes;
  final int goalMinutes;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress =
        goalMinutes <= 0 ? 0.0 : (todayMinutes / goalMinutes).clamp(0.0, 1.0);
    final done = todayMinutes >= goalMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: done
                    ? const [Color(0xFF1A5C4E), Color(0xFF2E7D5B)]
                    : [
                        MarefatColors.forest.withValues(alpha: 0.12),
                        MarefatColors.brass.withValues(alpha: 0.1),
                      ],
              ),
              border: Border.all(
                color: MarefatColors.forest.withValues(alpha: done ? 0 : 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      done
                          ? Icons.emoji_events_rounded
                          : Icons.flag_rounded,
                      color: done ? Colors.white : MarefatColors.forest,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        done ? 'هدف امروز کامل شد' : 'هدف مطالعهٔ روزانه',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: done ? Colors.white : MarefatColors.ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: done
                            ? Colors.white.withValues(alpha: 0.18)
                            : MarefatColors.mistDeep,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$streak روز پیاپی',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: done ? Colors.white : MarefatColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: done
                        ? Colors.white.withValues(alpha: 0.2)
                        : MarefatColors.mistDeep,
                    color: done ? const Color(0xFFD4B978) : MarefatColors.forest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$todayMinutes از $goalMinutes دقیقه',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: done
                        ? Colors.white.withValues(alpha: 0.85)
                        : MarefatColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06);
  }
}
