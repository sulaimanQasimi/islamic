import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/marefat_theme.dart';
import '../widgets/marefat_backdrop.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MarefatBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MarefatColors.ink, MarefatColors.forest],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: MarefatColors.forest.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.brightness_5_rounded,
                  color: MarefatColors.brassSoft,
                  size: 40,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 22),
              Text(
                'معرفت',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: MarefatColors.ink,
                      fontSize: 42,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 180.ms, duration: 500.ms)
                  .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'آرام بخوان، عمیق بیندیش',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MarefatColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ).animate().fadeIn(delay: 320.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
