import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';

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
    this.onViewCrProgress,
    this.onUnlockChallengerRoad,
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

  /// Called when a pro viewer taps "View Their Progress" for a target player
  /// with Challenger Road activity. Navigate to that player's profile/CR section.
  final VoidCallback? onViewCrProgress;

  /// Called when a free viewer taps "Unlock Challenger Road" for a pro player.
  /// Navigate to the Challenger Road paywall/teaser screen.
  final VoidCallback? onUnlockChallengerRoad;

  final List<UserAvatarPopoverAction> extraActions;
  final String viewProfileActionLabel;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return child;

    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: summaryStream ?? ChallengerRoadService().watchUserSummary(userId),
      builder: (context, snap) {
        final summary = snap.data ?? ChallengerRoadUserSummary.empty();

        final bool hasCrActivity = summary.totalAttempts > 0 || summary.allTimeBestLevel > 0 || summary.trophies.isNotEmpty;
        final bool viewerIsPro = Provider.of<CustomerInfoNotifier>(context, listen: false).isPro;
        // Show CR action whenever the target has activity (or is a pro placeholder),
        // regardless of whether the caller passed showAccomplishment.
        final bool hasCrAction = (hasCrActivity || showProFallback) && ((viewerIsPro && onViewCrProgress != null) || (!viewerIsPro && onUnlockChallengerRoad != null));
        final bool canOnlyViewProfile = !hasCrAction && onViewProfile != null && onEditAvatar == null && onShowQrCode == null && extraActions.isEmpty;

        if (!hasCrAction && canOnlyViewProfile) {
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
              if (value == 'cr_progress') {
                onViewCrProgress?.call();
              } else if (value == 'unlock_cr') {
                onUnlockChallengerRoad?.call();
              } else if (value == 'view') {
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

              if (hasCrAction) {
                if (viewerIsPro && onViewCrProgress != null) {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'cr_progress',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'View Their Progress'.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.onPrimary),
                        ],
                      ),
                    ),
                  );
                } else if (!viewerIsPro && onUnlockChallengerRoad != null) {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'unlock_cr',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Unlock Challenger Road'.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NovecentoSans',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Icon(Icons.lock_open_rounded, color: Theme.of(context).colorScheme.onPrimary),
                        ],
                      ),
                    ),
                  );
                }
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
                        Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.onPrimary),
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
