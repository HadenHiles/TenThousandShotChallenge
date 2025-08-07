import 'package:flutter/material.dart';
import 'dart:async';

class SwapCooldownTimer extends StatefulWidget {
  final int swapCount;
  final DateTime? lastSwap;
  final List<int> swapDelays;
  const SwapCooldownTimer({required this.swapCount, required this.lastSwap, required this.swapDelays, super.key});

  @override
  State<SwapCooldownTimer> createState() => _SwapCooldownTimerState();
}

class _SwapCooldownTimerState extends State<SwapCooldownTimer> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    if (widget.lastSwap == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final delayMs = widget.swapDelays.length > widget.swapCount ? widget.swapDelays[widget.swapCount] : widget.swapDelays.last;
    final nextAvailable = widget.lastSwap!.add(Duration(milliseconds: delayMs));
    final now = DateTime.now();
    setState(() {
      _remaining = nextAvailable.isAfter(now) ? nextAvailable.difference(now) : Duration.zero;
    });
  }

  @override
  void didUpdateWidget(covariant SwapCooldownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Icon(Icons.refresh, color: Theme.of(context).primaryColor, size: 30);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.timer, color: Colors.orange, size: 22),
        const SizedBox(width: 4),
        Text(_formatDuration(_remaining), style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
