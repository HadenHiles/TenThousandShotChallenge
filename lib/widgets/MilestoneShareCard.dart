import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// A self-contained share card rendered off-screen via [ScreenshotController],
/// then shared via the native share sheet.
///
/// Call [shareMilestone] - it renders the card to PNG bytes and triggers
/// the system share sheet with the image and an optional text caption.
Future<void> shareMilestone({
  required BuildContext context,
  required String title,
  required String subtitle,
  required int totalShots,
  String? displayName,
}) async {
  final controller = ScreenshotController();

  final Uint8List bytes = await controller.captureFromLongWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: MilestoneShareCard(
        title: title,
        subtitle: subtitle,
        totalShots: totalShots,
        displayName: displayName,
      ),
    ),
    pixelRatio: 3.0,
    delay: const Duration(milliseconds: 100),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/milestone_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: '${displayName != null ? "$displayName just " : "Just "}hit $title on #TenThousandShotChallenge 🏒',
  );
}

/// A visually rich share card widget.
class MilestoneShareCard extends StatelessWidget {
  const MilestoneShareCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.totalShots,
    this.displayName,
  });

  final String title;
  final String subtitle;
  final int totalShots;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return SizedBox(
      width: 360,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff1a1a2e), Color(0xff16213e), Color(0xff0f3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App identifier
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_hockey, color: Color(0xffCC3333), size: 22),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'TEN THOUSAND SHOT CHALLENGE',
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 12,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Trophy icon
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xffCC3333).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xffCC3333), size: 56),
              ),
              const SizedBox(height: 20),

              // Milestone title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 16,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 24),

              // Shot count badge
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    Text(
                      fmt.format(totalShots),
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 44,
                        color: Color(0xffCC3333),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'TOTAL SHOTS',
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 13,
                        color: Colors.white54,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              if (displayName != null) ...[
                const SizedBox(height: 20),
                Text(
                  displayName!,
                  style: const TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              Text(
                DateFormat('MMMM d, y').format(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
