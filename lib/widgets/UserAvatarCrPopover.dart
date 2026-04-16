import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarBadge.dart';

class UserAvatarPopoverAction {
  const UserAvatarPopoverAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
}

class UserAvatarCrPopover extends StatelessWidget {
  const UserAvatarCrPopover({
    super.key,
    required this.userId,
    required this.child,
    this.menuColor,
    this.showAccomplishment = true,
    this.showProFallback = false,
    this.summaryStream,
    this.onViewProfile,
    this.onEditAvatar,
    this.onShowQrCode,
    this.extraActions = const <UserAvatarPopoverAction>[],
    this.viewProfileActionLabel = 'Continue / View Profile',
  });

  final String userId;
  final Widget child;
  final Color? menuColor;
  final bool showAccomplishment;
  final bool showProFallback;
  final Stream<ChallengerRoadUserSummary>? summaryStream;
  final VoidCallback? onViewProfile;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onShowQrCode;
  final List<UserAvatarPopoverAction> extraActions;
  final String viewProfileActionLabel;

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
        final bool shouldShowAccomplishment = showAccomplishment && accomplishment != null && (hasCrActivity || showProFallback);
        final bool canOnlyViewProfile = onViewProfile != null && onEditAvatar == null && onShowQrCode == null && extraActions.isEmpty;

        if (!shouldShowAccomplishment && canOnlyViewProfile) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewProfile,
            child: child,
          );
        }

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
              } else if (value.startsWith('extra:')) {
                final idx = int.tryParse(value.substring(6));
                if (idx != null && idx >= 0 && idx < extraActions.length) {
                  final action = extraActions[idx];
                  if (action.enabled) action.onTap();
                }
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
                          accomplishment.icon ?? Icons.stairs_rounded,
                          color: accomplishment.color,
                          size: accomplishment.label == null ? 20 : 0,
                        ),
                        if (accomplishment.label != null)
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accomplishment.color,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              accomplishment.label!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
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
                          viewProfileActionLabel.toUpperCase(),
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

              if (extraActions.isNotEmpty) {
                for (int i = 0; i < extraActions.length; i++) {
                  final action = extraActions[i];
                  items.add(
                    PopupMenuItem<String>(
                      value: 'extra:$i',
                      enabled: action.enabled,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            action.label.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: action.enabled ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55),
                            ),
                          ),
                          Icon(
                            action.icon,
                            color: action.enabled ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  );
                }
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
