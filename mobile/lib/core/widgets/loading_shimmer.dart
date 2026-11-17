import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      period: const Duration(milliseconds: 1200),
      child: child ?? const _DefaultShimmerContent(),
    );
  }
}

class _DefaultShimmerContent extends StatelessWidget {
  const _DefaultShimmerContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(height: 180, borderRadius: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ShimmerBox(height: 100, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: _ShimmerBox(height: 100, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ShimmerBox(height: 100, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: _ShimmerBox(height: 100, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 20),
          _ShimmerBox(height: 20, width: 120, borderRadius: 8),
          const SizedBox(height: 12),
          _ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: 10),
          _ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: 10),
          _ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: 10),
          _ShimmerBox(height: 72, borderRadius: 16),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.height = 60,
    this.width,
    this.borderRadius = 12,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// Individual shimmer card helpers
class ShimmerMetricCard extends StatelessWidget {
  const ShimmerMetricCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ShimmerListItem extends StatelessWidget {
  const ShimmerListItem({super.key, this.height = 72});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
