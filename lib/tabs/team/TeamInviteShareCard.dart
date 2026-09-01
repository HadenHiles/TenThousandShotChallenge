import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';

/// Renders a team invite card off-screen and fires the native share sheet.
Future<void> shareTeamInvite(BuildContext context, Team team) async {
  final teamName = team.name ?? 'Our Team';
  final teamCode = team.code ?? '';

  final controller = ScreenshotController();

  final Uint8List bytes = await controller.captureFromLongWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 1.0),
      child: _TeamInviteCard(team: team),
    ),
    pixelRatio: 3.0,
    delay: const Duration(milliseconds: 120),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/team_invite_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes);

  final shareText = 'Join $teamName on 10,000 Shots! 🏒\n\n'
      'Team Code: $teamCode\n\n'
      '1. Download "10,000 Shots" on the App Store or Google Play\n'
      '2. Go to Community → Team → Join Team\n'
      '3. Scan the QR code or enter the team code above\n\n'
      'See you on the ice! 🎯';

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    text: shareText,
    subject: 'Join $teamName on 10,000 Shots!',
  );
}

class _TeamInviteCard extends StatelessWidget {
  const _TeamInviteCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final primaryColor = colorFromHex(team.primaryColor, fallback: const Color(0xFFCC3333));
    final darkAccent = team.darkAccentColor != null ? colorFromHex(team.darkAccentColor) : const Color(0xFF1A1A1A);
    final lightAccent = team.lightAccentColor != null ? colorFromHex(team.lightAccentColor) : Colors.white;

    final teamName = team.name ?? 'Our Team';
    final teamCode = team.code ?? '';
    final teamId = team.id ?? '';

    return SizedBox(
      width: 380,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: darkAccent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App branding row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_hockey, color: primaryColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'TEN THOUSAND SHOT CHALLENGE',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 11,
                      color: lightAccent.withValues(alpha: 0.55),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Team logo
              buildTeamLogoWidget(
                context: context,
                logoAsset: team.logoAsset,
                primaryColorHex: team.primaryColor,
                darkAccentHex: team.darkAccentColor,
                lightAccentHex: team.lightAccentColor,
                size: 72,
                iconSize: 36,
              ),

              const SizedBox(height: 16),

              // Team name
              Text(
                teamName.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 28,
                  color: lightAccent,
                  height: 1.1,
                ),
              ),

              if (team.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  team.description!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: lightAccent.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // QR code
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: teamId,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: primaryColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Team code box
              Text(
                'TEAM CODE',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 11,
                  color: lightAccent.withValues(alpha: 0.45),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Text(
                  teamCode,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 22,
                    color: lightAccent,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InstructionRow(
                      number: '1',
                      text: 'Download "10,000 Shots" on the\nApp Store or Google Play',
                      primaryColor: primaryColor,
                      textColor: lightAccent,
                    ),
                    const SizedBox(height: 8),
                    _InstructionRow(
                      number: '2',
                      text: 'Go to Community → Team → Join Team',
                      primaryColor: primaryColor,
                      textColor: lightAccent,
                    ),
                    const SizedBox(height: 8),
                    _InstructionRow(
                      number: '3',
                      text: 'Scan the QR code or enter the\nteam code above',
                      primaryColor: primaryColor,
                      textColor: lightAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.number,
    required this.text,
    required this.primaryColor,
    required this.textColor,
  });

  final String number;
  final String text;
  final Color primaryColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 13,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
