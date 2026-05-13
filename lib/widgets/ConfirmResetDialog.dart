import 'package:flutter/material.dart';

/// A modal dialog that requires the user to type a specific confirmation phrase
/// before a destructive action can be executed.
///
/// Usage:
/// ```dart
/// final confirmed = await showConfirmResetDialog(
///   context: context,
///   title: 'Restart Current Challenge',
///   description: 'This will delete all of your sessions…',
///   confirmPhrase: 'RESTART',
///   actionLabel: 'Restart',
///   actionColor: Colors.orange,
/// );
/// if (confirmed == true) { /* perform action */ }
/// ```
Future<bool?> showConfirmResetDialog({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmPhrase,
  required String actionLabel,
  Color? actionColor,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmResetDialog(
      title: title,
      description: description,
      confirmPhrase: confirmPhrase,
      actionLabel: actionLabel,
      actionColor: actionColor ?? Colors.red,
    ),
  );
}

class _ConfirmResetDialog extends StatefulWidget {
  const _ConfirmResetDialog({
    required this.title,
    required this.description,
    required this.confirmPhrase,
    required this.actionLabel,
    required this.actionColor,
  });

  final String title;
  final String description;
  final String confirmPhrase;
  final String actionLabel;
  final Color actionColor;

  @override
  State<_ConfirmResetDialog> createState() => _ConfirmResetDialogState();
}

class _ConfirmResetDialogState extends State<_ConfirmResetDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim() == widget.confirmPhrase;
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.primary,
      title: Text(
        widget.title,
        style: const TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 22,
        ),
      ),
      // SingleChildScrollView prevents RenderFlex overflow when the soft
      // keyboard pushes the dialog up on smaller screens.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.description,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Type  "${widget.confirmPhrase}"  to confirm:',
              style: TextStyle(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontFamily: 'NovecentoSans',
                fontSize: 16,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: widget.confirmPhrase,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                  fontFamily: 'NovecentoSans',
                  letterSpacing: 1.5,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.onPrimary.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.onPrimary.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _matches ? Colors.green : widget.actionColor,
                    width: 2,
                  ),
                ),
                suffixIcon: _matches ? const Icon(Icons.check_circle, color: Colors.green) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'CANCEL',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.actionColor,
            disabledBackgroundColor: widget.actionColor.withValues(alpha: 0.25),
            // Explicit foreground colours ensure text is legible in both states.
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
            textStyle: const TextStyle(fontFamily: 'NovecentoSans', fontWeight: FontWeight.w700),
          ),
          child: Text(widget.actionLabel.toUpperCase()),
        ),
      ],
    );
  }
}
