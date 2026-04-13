import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarBadge.dart';

class UserAvatarCrPopover extends StatelessWidget {
  const UserAvatarCrPopover({
    super.key,
    required this.userId,
    required this.child,
    this.menuColor,
    this.showProFallback = false,
    this.summaryStream,
    this.onViewProfile,
    this.onEditAvatar,
    this.onShowQrCode,
  });

  final String userId;
  final Widget child;
  final Color? menuColor;
  final bool showProFallback;
  final Stream<ChallengerRoadUserSummary>? summaryStream;
  final VoidCallback? onViewProfile;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onShowQrCode;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return child;

    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: summaryStream ?? ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        final summary = snap.data ?? ChallengerRoadUserSummary.empty();
        final accomplishment = resolveCrProfileAccomplishment(
          summary,
          showProFallback: showProFallback,
        );

        final bool hasCrActivity = summary.totalAttempts > 0 || summary.allTimeBestLevel > 0 || summary.badges.isNotEmpty;
        final bool shouldShowAccomplishment = accomplishment != null && (hasCrActivity || showProFallback);

        return Material(
          type: MaterialType.transparency,
          child: PopupMenuButton<String>(
            color: menuColor ?? Theme.of(context).colorScheme.primary,
            onSelected: (value) {
              if (value == 'view') {
                onViewProfile?.call();
              } else if (value == 'edit') {
                onEditAvatar?.call();
              } else if (value == 'qr') {
                onShowQrCode?.call();
              }
            },
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[];

              if (shouldShowAccomplishment) {
                items.add(
                  PopupMenuItem<String>(
                    enabled: false,
                    value: 'accomplishment',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          accomplishment.icon ?? Icons.emoji_events_rounded,
                          color: accomplishment.color,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                accomplishment.headline.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              if (accomplishment.subtitle != null)
                                Text(
                                  accomplishment.subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (onViewProfile != null) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'view',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'View Profile'.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimary),
                      ],
                    ),
                  ),
                );
              }

              if (onEditAvatar != null) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Avatar'.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary),
                      ],
                    ),
                  ),
                );
              }

              if (onShowQrCode != null) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'qr',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Show QR Code'.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        Icon(Icons.qr_code_2_rounded, color: Theme.of(context).colorScheme.onPrimary),
                      ],
                    ),
                  ),
                );
              }

              if (items.isEmpty) {
                items.add(
                  PopupMenuItem<String>(
                    enabled: false,
                    value: 'none',
                    child: Text(
                      'No profile actions'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                );
              }

              return items;
            },
            child: child,
          ),
        );
      },
    );
  }
}
