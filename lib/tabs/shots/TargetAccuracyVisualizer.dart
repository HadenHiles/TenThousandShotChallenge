import 'dart:math';
import 'package:flutter/material.dart';

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
    // Use up to 12 dots for clarity
    final int dotCount = total < 12 ? total : 12;
    final int hitDots = (accuracy * dotCount).round();
    final int missDots = dotCount - hitDots;

    // Dot size (smaller than before)
    final double dotSize = size * 0.08; // e.g. ~7px for size=90

    // Center and radii
    final double center = size / 2;
    final double innerRadius = size * 0.38; // max for hits
    final double minMissRadius = size * 0.48;
    final double maxMissRadius = size * 0.62;

    final random = Random(hits + total);

    // Use theme red for hit dots
    final Color hitDotColor = Theme.of(context).colorScheme.error;

    // Place hit dots: scatter them around the ring that represents the accuracy percentage
    // For example, 80% accuracy = dots around 80% of the radius (plus some variance)
    List<Widget> dots = [];
    for (int i = 0; i < hitDots; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      // The "target" radius for the hit dots is proportional to accuracy
      // 0% accuracy = near outer ring, 100% = near center
      final double baseRadius = innerRadius * (1 - accuracy);
      // Add a little random variance (5-10% of innerRadius)
      final double variance = innerRadius * (0.05 + random.nextDouble() * 0.05);
      final double r = baseRadius + (random.nextBool() ? variance : -variance);
      final double dx = center + r * cos(angle) - dotSize / 2;
      final double dy = center + r * sin(angle) - dotSize / 2;
      dots.add(Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: hitDotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: hitDotColor.withOpacity(0.18),
                blurRadius: 1.5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ));
    }

    // Place miss dots: always outside the target, never cut off
    for (int i = 0; i < missDots; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      final double r = minMissRadius + random.nextDouble() * (maxMissRadius - minMissRadius - dotSize / 2);
      final double dx = (center + r * cos(angle) - dotSize / 2).clamp(0, size - dotSize);
      final double dy = (center + r * sin(angle) - dotSize / 2).clamp(0, size - dotSize);
      dots.add(Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(120, 120, 120, 0.22),
            shape: BoxShape.circle,
          ),
        ),
      ));
    }

    return SizedBox(
      width: size,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Target rings (bottom layer)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.18),
            ),
          ),
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.32),
            ),
          ),
          Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shotColor.withOpacity(0.55),
            ),
          ),
          // Dots (hits and misses) - middle layer
          ...dots,
          // Center percentage (top layer, not cut off, not inside a circle)
          Positioned.fill(
            child: Center(
              child: Text(
                "${(accuracy * 100).round()}%",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'NovecentoSans',
                  fontSize: 13,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
