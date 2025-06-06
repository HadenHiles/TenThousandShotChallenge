import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TargetAccuracyVisualizer extends StatelessWidget {
  final int hits;
  final int total;
  final Color shotColor;
  final double size;

  const TargetAccuracyVisualizer({
    super.key,
    required this.hits,
    required this.total,
    required this.shotColor,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate accuracy
    final double accuracy = total > 0 ? hits / total : 0.0;
    // For fun, max 12 dots (for clarity)
    final int dotCount = total < 12 ? total : 12;
    final int hitDots = (accuracy * dotCount).round();
    final int missDots = dotCount - hitDots;

    // Place hit dots evenly around the target
    List<Widget> dots = [];
    final double center = size / 2;
    final double radius = size * 0.38;
    for (int i = 0; i < hitDots; i++) {
      final double angle = (2 * pi / dotCount) * i - pi / 2;
      final double dx = center + radius * cos(angle) - 8;
      final double dy = center + radius * sin(angle) - 8;
      dots.add(Positioned(
        left: dx,
        top: dy,
        child: Icon(
          FontAwesomeIcons.hockeyPuck,
          size: 16,
          color: shotColor,
        ),
      ));
    }

    // Place miss dots randomly outside the target
    final double missRadiusMin = size * 0.48;
    final double missRadiusMax = size * 0.62;
    final random = Random(hits + total); // deterministic for same input
    for (int i = 0; i < missDots; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      final double r = missRadiusMin + random.nextDouble() * (missRadiusMax - missRadiusMin);
      final double dx = center + r * cos(angle) - 8;
      final double dy = center + r * sin(angle) - 8;
      dots.add(Positioned(
        left: dx,
        top: dy,
        child: Icon(
          FontAwesomeIcons.hockeyPuck,
          size: 16,
          color: Colors.grey.withOpacity(0.28),
        ),
      ));
    }

    return SizedBox(
      width: size,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.18),
            ),
          ),
          // Middle ring
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.32),
            ),
          ),
          // Inner ring
          Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.55),
            ),
          ),
          // Center
          Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor,
            ),
            alignment: Alignment.center,
            child: Text(
              "${(accuracy * 100).round()}%",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'NovecentoSans',
                fontSize: 14,
              ),
            ),
          ),
          // Dots (hits and misses)
          ...dots,
          // Label below
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Text(
              "$hits / $total",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: shotColor,
                fontFamily: 'NovecentoSans',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
