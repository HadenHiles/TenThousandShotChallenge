import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rotating_icon_button/rotating_icon_button.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamInviteShareCard.dart';
import 'package:word_generator/word_generator.dart';

void showQRCode(BuildContext context, User? user) {
  if (user == null) return;
  final Color qrColor = Theme.of(context).primaryColor;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // Mirror the team QR container/ring colors using app surface colours:
      //   darkSurface  = colorScheme.primary  (0xff1A1A1A dark / white light)
      //   lightSurface = colorScheme.surface   (0xff222222 dark / white light)
      final darkSurface = Theme.of(context).colorScheme.primary;
      final lightSurface = Theme.of(context).colorScheme.surface;

      // Ring geometry - same formula as buildTeamLogoWidget, size = 52
      const double avatarSize = 52;
      final double ringWidth = (avatarSize * 0.07).clamp(2.5, 5.0);
      final double lightRingWidth = ringWidth * 0.5;
      final double innerSize = avatarSize - ringWidth * 2 - lightRingWidth * 2;

      return AlertDialog(
        title: Text(
          "Friend QR Code".toUpperCase(),
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 20,
            color: qrColor,
          ),
        ),
        backgroundColor: lightSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                "Have friends scan this code to add you.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: darkSurface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: ringWidth),
              ),
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: user.uid,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: qrColor,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: qrColor,
                      ),
                    ),
                    // Profile photo with triple-ring structure matching buildTeamLogoWidget
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: qrColor.withValues(alpha: 0.40),
                            blurRadius: avatarSize * 0.28,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: avatarSize - ringWidth * 2,
                          height: avatarSize - ringWidth * 2,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle),
                          child: Center(
                            child: Container(
                              width: innerSize,
                              height: innerSize,
                              decoration: BoxDecoration(color: darkSurface, shape: BoxShape.circle),
                              clipBehavior: Clip.antiAlias,
                              child: user.photoURL != null ? Image.network(user.photoURL!, fit: BoxFit.cover) : Icon(Icons.person_rounded, color: qrColor, size: innerSize * 0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Close".toUpperCase(),
              style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      );
    },
  );
}

Future<bool> showTeamQRCode(BuildContext context, {String? activeTeamId}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    // Resolve which team to show: prefer the actively-viewed team, fall back to
    // the user's first team from their profile.
    String? teamId = activeTeamId;
    if (teamId == null || teamId.isEmpty) {
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final u = UserProfile.fromSnapshot(uDoc);
      teamId = u.teamId;
    }
    if (teamId == null || teamId.isEmpty) return false;

    return FirebaseFirestore.instance.collection('teams').doc(teamId).get().then((tDoc) {
      Team team = Team.fromSnapshot(tDoc);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          Team t = team;
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              final primaryColor = colorFromHex(t.primaryColor);
              final darkAccent = colorFromHex(t.darkAccentColor, fallback: const Color(0xFF1A1A1A));
              final lightAccent = colorFromHex(t.lightAccentColor, fallback: Colors.white);
              final onSurface = Theme.of(context).colorScheme.onSurface;
              final surface = Theme.of(context).colorScheme.surface;

              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                backgroundColor: surface,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Dark header with team identity ───────────────────
                        Container(
                          color: darkAccent,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          child: Column(
                            children: [
                              buildTeamLogoWidget(
                                context: context,
                                logoAsset: t.logoAsset,
                                primaryColorHex: t.primaryColor,
                                darkAccentHex: t.darkAccentColor,
                                lightAccentHex: t.lightAccentColor,
                                size: 64,
                                iconSize: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                (t.name ?? 'Team').toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 24, color: lightAccent, height: 1.1),
                              ),
                              if (t.description?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  t.description!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: lightAccent.withValues(alpha: 0.6), height: 1.3),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── QR code ─────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 3))],
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: team.id!,
                                    version: QrVersions.auto,
                                    size: 160,
                                    backgroundColor: Colors.white,
                                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                                    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: primaryColor),
                                    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: primaryColor),
                                  ),
                                  if (t.logoAsset != null)
                                    buildTeamLogoWidget(
                                      context: context,
                                      logoAsset: t.logoAsset,
                                      primaryColorHex: t.primaryColor,
                                      darkAccentHex: t.darkAccentColor,
                                      lightAccentHex: t.lightAccentColor,
                                      size: 46,
                                      iconSize: 23,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Team code ────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            children: [
                              Text('TEAM CODE', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: onSurface.withValues(alpha: 0.45), letterSpacing: 1.5)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
                                      ),
                                      child: AutoSizeText(
                                        t.code ?? '',
                                        maxLines: 1,
                                        minFontSize: 12,
                                        style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: onSurface, letterSpacing: 2),
                                      ),
                                    ),
                                  ),
                                  if (t.ownerId == user.uid) ...[
                                    const SizedBox(width: 4),
                                    RotatingIconButton(
                                      onTap: () async {
                                        final wordGenerator = WordGenerator();
                                        final newCode = wordGenerator.randomNoun().toUpperCase() + wordGenerator.randomVerb().toUpperCase() + Random().nextInt(9999).toString().padLeft(4, '0');
                                        await FirebaseFirestore.instance.collection('teams').doc(t.id).update({'code': newCode});
                                        setState(() => t.code = newCode);
                                      },
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      borderRadius: 20,
                                      rotateType: RotateType.full,
                                      duration: const Duration(milliseconds: 1000),
                                      curve: Curves.easeInOut,
                                      clockwise: true,
                                      padding: const EdgeInsets.all(8),
                                      background: Colors.transparent,
                                      child: Icon(Icons.refresh_rounded, color: primaryColor),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Actions ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.ios_share_rounded, size: 18),
                                  label: Text('Share Invite'.toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 15)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                  ),
                                  onPressed: () => shareTeamInvite(context, t),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('Close'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: onSurface.withValues(alpha: 0.6))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return true;
    });
  } else {
    return false;
  }
}
