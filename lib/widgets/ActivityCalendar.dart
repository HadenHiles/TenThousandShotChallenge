import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/services/LocalNotificationService.dart';

/// GitHub-style contribution heatmap showing the last 52 weeks of training days.
///
/// - Cell colour intensity is proportional to shot volume that day.
/// - Below the grid: current streak and longest-streak labels.
/// - Tapping a cell shows a tooltip with the date and shot count.
class ActivityCalendar extends StatefulWidget {
  /// When provided, loads activity for this user instead of the signed-in user.
  /// Streak notifications are only scheduled for the current user (when null).
  final String? userId;

  const ActivityCalendar({super.key, this.userId});

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  // Map of date-string (yyyy-MM-dd) → total shots
  Map<String, int> _dailyShots = {};
  bool _loading = true;

  // Tooltip state
  String? _tooltipDate;
  int? _tooltipShots;
  Offset? _tooltipOffset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ───────────────────────────────────────────────────────

  Future<void> _load() async {
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final uid = widget.userId ?? auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Firestore path: iterations/{uid}/iterations/{iterationId}/sessions
      final iterSnap = await firestore.collection('iterations').doc(uid).collection('iterations').get();

      final Map<String, int> daily = {};
      for (final iter in iterSnap.docs) {
        final sessSnap = await iter.reference.collection('sessions').get();
        for (final sess in sessSnap.docs) {
          final data = sess.data();
          final dynamic rawDate = data['date'];
          DateTime? date;
          if (rawDate is Timestamp) {
            date = rawDate.toDate();
          } else if (rawDate is DateTime) {
            date = rawDate;
          }
          if (date == null) continue;
          final key = DateFormat('yyyy-MM-dd').format(date);
          final total = (data['total'] as int? ?? 0);
          daily[key] = (daily[key] ?? 0) + total;
        }
      }

      if (mounted) {
        setState(() {
          _dailyShots = daily;
          _loading = false;
        });

        // Only manage streak notifications for the current user's own calendar.
        if (widget.userId == null) {
          _updateStreakNotification(daily);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Streak helpers ─────────────────────────────────────────────────────

  /// Schedule the streak-at-risk notification if the user has a streak and
  /// hasn't practiced today; cancel it if they already practiced today.
  Future<void> _updateStreakNotification(Map<String, int> daily) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final practiced = daily.containsKey(today);
    if (practiced) {
      await LocalNotificationService.cancelStreakAtRisk();
    } else {
      final streak = _currentStreak();
      if (streak >= 2) {
        await LocalNotificationService.scheduleStreakAtRisk(streakDays: streak);
      } else {
        await LocalNotificationService.cancelStreakAtRisk();
      }
    }
  }

  int _currentStreak() {
    if (_dailyShots.isEmpty) return 0;
    final today = DateTime.now();
    int streak = 0;
    for (int i = 0; i <= 365; i++) {
      final d = today.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      if (_dailyShots.containsKey(key)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  int _longestStreak() {
    if (_dailyShots.isEmpty) return 0;
    final keys = _dailyShots.keys.map((k) => DateFormat('yyyy-MM-dd').parse(k)).toList()..sort();
    int longest = 1;
    int current = 1;
    for (int i = 1; i < keys.length; i++) {
      if (keys[i].difference(keys[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Build 52-week grid (364 days back from today, plus today = 364 cells
    // arranged in 7-row columns for each week, oldest column on the left).
    final today = DateTime.now();
    final totalDays = 52 * 7;
    final gridStart = today.subtract(Duration(days: totalDays - 1));

    // 250 shots = full intensity; scale is fixed so colours are meaningful
    // across all users regardless of their personal max.
    const double shotScaleMax = 250.0;

    const cellSize = 12.0;
    const cellGap = 2.0;
    const cols = 52;
    const rows = 7;

    DateTime? lastMonthDate;
    int? lastLabelYear;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels + grid scroll together; streak/legend stays fixed below.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month labels (left = most recent, right = oldest)
              SizedBox(
                width: cols * (cellSize + cellGap),
                height: 16,
                child: Builder(builder: (ctx) {
                  final colWidth = cellSize + cellGap;
                  final labels = <Widget>[];
                  for (int col = 0; col < cols; col++) {
                    // Reversed: col 0 = most recent week, col 51 = oldest week
                    final day = gridStart.add(Duration(days: (cols - 1 - col) * 7));
                    if (lastMonthDate == null || day.month != lastMonthDate!.month) {
                      lastMonthDate = day;
                      // Show year whenever the year changes (or on the very first label)
                      final showYear = lastLabelYear == null || day.year != lastLabelYear;
                      lastLabelYear = day.year;
                      final label = showYear ? DateFormat("MMM ''yy").format(day) : DateFormat('MMM').format(day);
                      labels.add(Positioned(
                        left: col * colWidth,
                        child: Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      ));
                    }
                  }
                  return Stack(children: labels);
                }),
              ),
              const SizedBox(height: 4),
              // Grid
              GestureDetector(
                onTapDown: (details) {
                  final colWidth = cellSize + cellGap;
                  final rowHeight = cellSize + cellGap;
                  final col = (details.localPosition.dx / colWidth).floor().clamp(0, cols - 1);
                  final row = (details.localPosition.dy / rowHeight).floor().clamp(0, rows - 1);
                  // Reversed: col 0 = most recent week
                  final date = gridStart.add(Duration(days: (cols - 1 - col) * 7 + row));
                  if (date.isAfter(today)) return;
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  setState(() {
                    _tooltipDate = DateFormat('MMM d, y').format(date);
                    _tooltipShots = _dailyShots[key] ?? 0;
                    _tooltipOffset = details.localPosition;
                  });
                },
                onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _tooltipDate = null);
                }),
                child: SizedBox(
                  width: cols * (cellSize + cellGap),
                  height: rows * (cellSize + cellGap),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(cols * (cellSize + cellGap), rows * (cellSize + cellGap)),
                        painter: _HeatmapPainter(
                          gridStart: gridStart,
                          today: today,
                          dailyShots: _dailyShots,
                          shotScaleMax: shotScaleMax,
                          primaryColor: Theme.of(context).primaryColor,
                          emptyColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                          cellSize: cellSize,
                          cellGap: cellGap,
                          cols: cols,
                          rows: rows,
                        ),
                      ),
                      if (_tooltipDate != null && _tooltipOffset != null)
                        Positioned(
                          left: (_tooltipOffset!.dx - 60).clamp(0, cols * (cellSize + cellGap) - 120),
                          top: (_tooltipOffset!.dy - 44).clamp(0, double.infinity),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_tooltipDate!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('${_tooltipShots ?? 0} shots', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Streak badges + legend - outside the scroll so they pin to the card width.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _StreakBadge(
                  icon: Icons.local_fire_department,
                  label: '${_currentStreak()} day streak',
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _StreakBadge(
                  icon: Icons.emoji_events_outlined,
                  label: 'Best: ${_longestStreak()} days',
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            Row(
              children: [
                Text('Less', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(width: 4),
                ...List.generate(5, (i) {
                  final opacity = 0.1 + i * 0.22;
                  return Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text('More', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.gridStart,
    required this.today,
    required this.dailyShots,
    required this.shotScaleMax,
    required this.primaryColor,
    required this.emptyColor,
    required this.cellSize,
    required this.cellGap,
    required this.cols,
    required this.rows,
  });

  final DateTime gridStart;
  final DateTime today;
  final Map<String, int> dailyShots;
  final double shotScaleMax;
  final Color primaryColor;
  final Color emptyColor;
  final double cellSize;
  final double cellGap;
  final int cols;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final fmt = DateFormat('yyyy-MM-dd');

    for (int col = 0; col < cols; col++) {
      for (int row = 0; row < rows; row++) {
        // Reversed: col 0 = most recent week, col (cols-1) = oldest week
        final date = gridStart.add(Duration(days: (cols - 1 - col) * 7 + row));
        if (date.isAfter(today)) continue;

        final key = fmt.format(date);
        final shots = dailyShots[key] ?? 0;

        if (shots == 0) {
          paint.color = emptyColor;
        } else {
          final opacity = (shots / shotScaleMax).clamp(0.15, 1.0);
          paint.color = primaryColor.withValues(alpha: opacity);
        }

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            col * (cellSize + cellGap),
            row * (cellSize + cellGap),
            cellSize,
            cellSize,
          ),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.dailyShots != dailyShots || old.shotScaleMax != shotScaleMax;
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'NovecentoSans',
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
