import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/marefat_theme.dart';

class ShimmerLibrary extends StatelessWidget {
  const ShimmerLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final base = MarefatColors.mistDeep;
    final highlight = Colors.white.withValues(alpha: 0.85);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(height: 28, width: 140, radius: 10),
                  const SizedBox(height: 10),
                  _box(height: 14, width: 220, radius: 8),
                  const SizedBox(height: 22),
                  _box(height: 110, radius: 22),
                  const SizedBox(height: 18),
                  _box(height: 18, width: 100, radius: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => _box(radius: 18),
                childCount: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({double? height, double? width, double radius = 14}) =>
      Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
