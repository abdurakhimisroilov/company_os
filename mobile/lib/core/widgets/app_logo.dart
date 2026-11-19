import 'package:flutter/material.dart';

/// The Opero app icon as a rounded badge (login, splash, PIN lock, dashboard).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    required this.borderRadius,
    this.shadowOpacity = 0.35,
    this.shadowBlur = 20,
    this.shadowOffsetY = 8,
  });

  final double size;
  final double borderRadius;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowOffsetY;

  static const Color _brandGreen = Color(0xFF0B6B4A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: _brandGreen.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/branding/opero_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
