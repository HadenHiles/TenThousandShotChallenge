import 'package:flutter/material.dart';

class ShotTypeButton extends StatelessWidget {
  const ShotTypeButton({
    super.key,
    required this.type,
    required this.active,
    required this.onPressed,
    this.borderRadius,
  });

  final String type;
  final bool active;
  final VoidCallback onPressed;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: InkWell(
        borderRadius: borderRadius ?? BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(6),
          ),
          child: Text(
            type.toUpperCase(),
            style: TextStyle(
              color: active ? Colors.white.withValues(alpha: 1) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontFamily: 'NovecentoSans',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}
