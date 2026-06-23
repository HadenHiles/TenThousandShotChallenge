// ignore_for_file: constant_identifier_names

import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; // For QRCodeDialog
import 'package:rxdart/rxdart.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamLeaderboardPdf.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarTrophy.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatarCrPopover.dart';
import 'package:tenthousandshotchallenge/Navigation.dart' show openChallengerRoadSignal, activeTeamIdNotifier;
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const TEAM_HEADER_HEIGHT = 65.0;

// QRCodeDialog Class (Included directly in this file for simplicity)
class QRCodeDialog extends StatelessWidget {
  final String title;
  final String data;
  final String? message;
  // When provided, team colors + logo are applied to the QR code
  final Team? team;

  const QRCodeDialog({
    super.key,
    required this.title,
    required this.data,
    this.message,
    this.team,
  });

  @override
  Widget build(BuildContext context) {
    final Color qrColor = team != null ? colorFromHex(team!.primaryColor) : Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          color: qrColor,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          Container(
            decoration: team != null
                ? BoxDecoration(
                    color: colorFromHex(team!.darkAccentColor, fallback: const Color(0xFF111111)).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: qrColor.withValues(alpha: 0.5), width: 1.5),
                  )
                : null,
            padding: team != null ? const EdgeInsets.all(10) : EdgeInsets.zero,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: data,
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
                  if (team?.logoAsset != null)
                    buildTeamLogoWidget(
                      context: context,
                      logoAsset: team!.logoAsset,
                      primaryColorHex: team!.primaryColor,
                      darkAccentHex: team!.darkAccentColor,
                      lightAccentHex: team!.lightAccentColor,
                      size: 52,
                      iconSize: 26,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            "Close".toUpperCase(),
            style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onSurface),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// displayTeamQRCodeDialog function (Included directly in this file for simplicity)
Future<bool> displayTeamQRCodeDialog(BuildContext context, String? teamId, String? teamName, {Team? team}) async {
  if (teamId != null && teamId.isNotEmpty && teamName != null && teamName.isNotEmpty) {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => QRCodeDialog(
        title: "Team QR Code",
        data: teamId,
        message: "Have new players scan this code to join '$teamName'.",
        team: team,
      ),
    );
    return true;
  }
  Fluttertoast.showToast(msg: "Team information is incomplete for QR sharing.");
  return false;
}

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class Plyr {
  UserProfile? profile;
  int? shots;

  Plyr(this.profile, this.shots);
}

class _TeamPageState extends State<TeamPage> with SingleTickerProviderStateMixin {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;
  final TextEditingController _targetDateController = TextEditingController();
  bool _showShotsPerDay = true;

  final NumberFormat numberFormat = NumberFormat("###,###,###", "en_US");

  // Cached team for use in builder helper methods
  Team? _currentTeam;

  // Multi-team: index of the tab currently shown in the switcher.
  int _selectedTeamIndex = 0;
  // Tracks how many teams the user had on the previous build so we can detect
  // when a new team is appended (e.g. after joining) and auto-select it.
  int _lastKnownTeamCount = 0;
  // Animation controller for the long-press scale effect on the team header card.
  late AnimationController _cardPressController;
  late Animation<double> _cardScaleAnim;

  static const _kSelectedTeamIndexKey = 'selected_team_index';

  @override
  void initState() {
    super.initState();
    _loadSavedTeamIndex();
    _cardPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _cardScaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _cardPressController,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  Future<void> _loadSavedTeamIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedTeamIndexKey) ?? 0;
    if (mounted && saved != 0) setState(() => _selectedTeamIndex = saved);
  }

  Future<void> _saveTeamIndex(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_kSelectedTeamIndexKey, idx);
  }

  @override
  void dispose() {
    _cardPressController.dispose();
    super.dispose();
  }

  // ── Pro subscription status banner ──────────────────────────────────────────
  // Shown only when the user has 2+ teams (a Pro-dependent state).
  // • Pre-expiry (≤7 days): amber warning with countdown.
  // • Post-expiry: muted notice confirming grandfathering + renew CTA.
  // • Active Pro with >7 days left: returns nothing (SizedBox.shrink).
  Widget _buildProStatusBanner({required bool isPro, required int teamCount}) {
    if (isPro) {
      final expiryDate = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.latestExpirationDateTime;
      if (expiryDate == null) return const SizedBox.shrink();
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
      if (daysLeft > 7) return const SizedBox.shrink();

      // ── Pre-expiry warning ───────────────────────────────────────────
      final dayLabel = daysLeft <= 0 ? 'today' : 'in $daysLeft day${daysLeft == 1 ? '' : 's'}';
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade800.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: Colors.amber.shade400, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pro expires $dayLabel - your $teamCount teams will be preserved but you won\'t be able to add more.',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade300),
              ),
            ),
            TextButton(
              onPressed: () => presentPaywallIfNeeded(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Renew', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Colors.amber.shade300)),
            ),
          ],
        ),
      );
    }

    // ── Post-expiry notice ─────────────────────────────────────────────
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pro ended - your $teamCount teams are kept. Renew to create or join more.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)),
            ),
          ),
          TextButton(
            onPressed: () => presentPaywallIfNeeded(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Renew', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55))),
          ),
        ],
      ),
    );
  }

  // ── Team switcher bottom sheet (shown when user belongs to 2+ teams) ────────
  void _showTeamSwitcherSheet(List<String> teamIds, List<Team?> allTeams, int selectedIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Switch Team'.toUpperCase(),
                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Theme.of(sheetCtx).colorScheme.onPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: teamIds.length,
                itemBuilder: (_, i) {
                  final t = i < allTeams.length ? allTeams[i] : null;
                  final label = t?.name ?? '...';
                  final color = colorFromHex(t?.primaryColor);
                  final isSelected = i == selectedIndex;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: buildTeamLogoWidget(
                      context: sheetCtx,
                      logoAsset: t?.logoAsset,
                      primaryColorHex: t?.primaryColor,
                      darkAccentHex: t?.darkAccentColor,
                      lightAccentHex: t?.lightAccentColor,
                      size: 40,
                      iconSize: 20,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 19,
                        color: isSelected ? color : Theme.of(sheetCtx).colorScheme.onPrimary,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 22) : null,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (mounted && i != _selectedTeamIndex) {
                        setState(() => _selectedTeamIndex = i);
                        _saveTeamIndex(i);
                      }
                    },
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserProfileStream() {
    return Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(user!.uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getTeamStream(String teamId) {
    return Provider.of<FirebaseFirestore>(context, listen: false).collection('teams').doc(teamId).snapshots();
  }

  // Stream for a single player's data (profile + total shots)
  Stream<Plyr> _getSinglePlayerDataStream(String playerUid, DateTime teamStartDate, DateTime teamTargetDate) {
    final userProfileStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(playerUid).snapshots().map((snap) {
      if (snap.exists) {
        return UserProfile.fromSnapshot(snap);
      }
      // Create a placeholder for deleted users (when Firestore document doesn't exist)
      return UserProfile("Deleted User", null, null, null, null, null, null);
    });

    // Stream of total shots for this player
    final playerTotalShotsStream = Provider.of<FirebaseFirestore>(context, listen: false)
        .collection('iterations') // Root iterations collection
        .doc(playerUid) // Document ID is the user's UID
        .collection('iterations') // Subcollection of iterations for this user
        .snapshots() // Stream<QuerySnapshot> of the user's iterations
        .switchMap((iterationsSnapshot) {
          // When iterations change, get new session sums
          if (iterationsSnapshot.docs.isEmpty) {
            return Stream.value(0); // No iterations, so 0 shots
          }

          List<Stream<int>> iterationShotSumStreams = iterationsSnapshot.docs.map((iterationDoc) {
            // For each iteration, stream its sessions and sum the 'total' field for sessions
            // that fall within the team goal window [teamStartDate, teamTargetDate].
            final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
            return firestore
                .collection('iterations')
                .doc(playerUid)
                .collection('iterations')
                .doc(iterationDoc.id)
                .collection('sessions')
                // We'll listen to all sessions and filter client-side to keep logic clear and avoid composite indexes.
                .snapshots()
                .map((sessionsSnapshot) {
              int sum = 0;
              for (final sessionDoc in sessionsSnapshot.docs) {
                final data = sessionDoc.data();
                // Expect Firestore Timestamp in 'date'
                final dynamic rawDate = data['date'];
                DateTime? sessionDate;
                if (rawDate is Timestamp) {
                  sessionDate = rawDate.toDate();
                } else if (rawDate is DateTime) {
                  sessionDate = rawDate;
                }
                if (sessionDate == null) continue;
                // Normalize to date (remove time) for inclusive comparison
                final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
                final startDay = DateTime(teamStartDate.year, teamStartDate.month, teamStartDate.day);
                final endDay = DateTime(teamTargetDate.year, teamTargetDate.month, teamTargetDate.day);
                if (sessionDay.isBefore(startDay) || sessionDay.isAfter(endDay)) {
                  continue; // Outside team goal window
                }
                final dynamic totalVal = data['total'];
                if (totalVal is int) {
                  sum += totalVal;
                } else if (totalVal is num) {
                  sum += totalVal.toInt();
                }
              }
              return sum;
            }).handleError((e) {
              // On error for this iteration's sessions, return 0 so other iterations still count
              return 0;
            });
          }).toList();

          if (iterationShotSumStreams.isEmpty) {
            return Stream.value(0);
          }

          // Combine the sums from all iterations for this player
          return CombineLatestStream.list<int>(iterationShotSumStreams).map((listOfShotSums) => listOfShotSums.fold(0, (prev, sum) => prev + sum)).startWith(0); // Emit 0 initially until sums are calculated
        })
        .startWith(0)
        .handleError((e) {
          // print("Error in playerTotalShotsStream for $playerUid: $e");
          return 0; // Return 0 shots for player on error
        });

    return CombineLatestStream.combine2(
      userProfileStream,
      playerTotalShotsStream,
      (UserProfile profile, int totalShots) => Plyr(profile, totalShots),
    ).handleError((error) {
      // print("Error combining profile and shots for $playerUid: $error");
      // Fallback Plyr object for errors (keep as Loading to filter out)
      return Plyr(UserProfile("Loading...", "Loading...", null, null, null, null, null), 0);
    });
  }

  Stream<List<Plyr>> _getTeamPlayersDataStream(List<String> playerUids, DateTime teamStartDate, DateTime teamTargetDate) {
    if (playerUids.isEmpty) {
      return Stream.value([]);
    }

    List<Stream<Plyr>> playerStreams = playerUids.map((uid) {
      return _getSinglePlayerDataStream(uid, teamStartDate, teamTargetDate);
    }).toList();

    return CombineLatestStream.list<Plyr>(playerStreams).map((listOfPlyrs) {
      // Include deleted users but filter out loading/error states
      var validPlyrs = listOfPlyrs.where((p) => p.profile?.displayName != null && p.profile!.displayName != "Loading..." && p.profile!.displayName != "Error").toList();
      validPlyrs.sort((a, b) => (b.shots ?? 0).compareTo(a.shots ?? 0));
      return validPlyrs;
    }).handleError((error, stackTrace) {
      // print("Error in _getTeamPlayersDataStream: $error \n$stackTrace");
      return [];
    });
  }

  Map<String, String> _calculateShotTexts(int teamTotalShots, Team teamData, int numPlayers) {
    int currentTeamTotalShots = teamTotalShots;
    int goalTotal = teamData.goalTotal!;
    DateTime targetDate = teamData.targetDate!;

    int shotsRemaining = goalTotal - currentTeamTotalShots;
    final now = DateTime.now();
    final normalizedTargetDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedToday = DateTime(now.year, now.month, now.day);

    int daysRemaining = normalizedTargetDate.difference(normalizedToday).inDays;
    double weeksRemaining = daysRemaining / 7;

    if (numPlayers <= 0) numPlayers = 1;

    int shotsPerDay = 0;
    if (daysRemaining <= 0) {
      shotsPerDay = shotsRemaining > 0 ? shotsRemaining : 0;
    } else {
      shotsPerDay = shotsRemaining <= 0 ? 0 : (shotsRemaining / daysRemaining).ceil();
    }
    if (shotsPerDay < 0) shotsPerDay = 0;

    int shotsPerWeek = 0;
    if (weeksRemaining <= 0) {
      shotsPerWeek = shotsRemaining > 0 ? shotsRemaining : 0;
    } else {
      shotsPerWeek = shotsRemaining <= 0 ? 0 : (shotsRemaining.toDouble() / weeksRemaining).ceil().toInt();
    }
    if (shotsPerWeek < 0) shotsPerWeek = 0;

    int shotsPerPlayerDay = (shotsPerDay / numPlayers).round();
    int shotsPerPlayerWeek = (shotsPerWeek / numPlayers).round();

    String finalShotsPerDayText;
    String finalShotsPerWeekText;

    if (normalizedTargetDate.isBefore(normalizedToday)) {
      // Target date is in the past
      int daysPast = normalizedToday.difference(normalizedTargetDate).inDays;
      finalShotsPerDayText = "${daysPast.abs()} Days Past Goal".toLowerCase();
      finalShotsPerWeekText = shotsRemaining <= 0 ? "Goal Met!".toLowerCase() : (shotsRemaining <= 999 ? "$shotsRemaining remaining".toLowerCase() : "${numberFormat.format(shotsRemaining)} remaining".toLowerCase());
    } else {
      // Future goal date or today
      finalShotsPerDayText = shotsRemaining < 1
          ? "Done!".toLowerCase()
          : shotsPerPlayerDay <= 999
              ? "$shotsPerPlayerDay / Day / Player".toLowerCase()
              : "${numberFormat.format(shotsPerPlayerDay)} / Day / Player".toLowerCase();
      finalShotsPerWeekText = shotsRemaining < 1
          ? "Done!".toLowerCase()
          : shotsPerPlayerWeek <= 999
              ? "$shotsPerPlayerWeek / Week / Player".toLowerCase()
              : "${numberFormat.format(shotsPerPlayerWeek)} / Week / Player".toLowerCase();
    }

    return {
      'shotsPerDayText': finalShotsPerDayText,
      'shotsPerWeekText': finalShotsPerWeekText,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('team_tab_body'),
      padding: isThreeButtonAndroidNavigation(context)
          ? EdgeInsets.only(bottom: sessionService.isRunning ? MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 65 : MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight)
          : sessionService.isRunning
              ? EdgeInsets.only(bottom: 65)
              : EdgeInsets.zero,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _getUserProfileStream(),
        builder: (context, userProfileSnapshot) {
          if (userProfileSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          }
          if (!userProfileSnapshot.hasData || !userProfileSnapshot.data!.exists) {
            return const Center(child: Text("Error loading user profile. Please restart the app."));
          }

          UserProfile currentUserProfile = UserProfile.fromSnapshot(userProfileSnapshot.data!);
          final List<String> teamIds = currentUserProfile.teamIds;

          // Auto-select the last (most recently joined) team when the list grows.
          // Use addPostFrameCallback so setState is never called during a build.
          if (teamIds.length > _lastKnownTeamCount && _lastKnownTeamCount > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final newIdx = teamIds.length - 1;
                setState(() => _selectedTeamIndex = newIdx);
                _saveTeamIndex(newIdx);
              }
            });
          }
          _lastKnownTeamCount = teamIds.length;

          if (teamIds.isEmpty) {
            return _buildNoTeamUI();
          }

          // Clamp selected index in case teams were removed while viewing
          final int safeIndex = _selectedTeamIndex.clamp(0, teamIds.length - 1);
          final String activeTeamId = teamIds[safeIndex];

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getTeamStream(activeTeamId),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
              }
              if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                return _buildTeamRemovedOrNotFoundUI(null, currentUserProfile.reference, activeTeamId);
              }

              Team team = Team.fromSnapshot(teamSnapshot.data!);
              bool isCurrentUserOwner = team.ownerId == user?.uid;
              _targetDateController.text = DateFormat('MMMM d, y').format(team.targetDate ?? DateTime.now().add(const Duration(days: 100)));

              if (!(team.players?.contains(user?.uid) ?? false)) {
                return _buildTeamRemovedOrNotFoundUI(team.name, currentUserProfile.reference, activeTeamId);
              }

              // Pre-load sibling team names for the switcher tabs by streaming
              // all teams in parallel and building a lightweight name list.
              return StreamBuilder<List<Team?>>(
                stream: teamIds.length > 1
                    ? CombineLatestStream.list(
                        teamIds
                            .map((id) => _getTeamStream(id).map(
                                  (snap) => snap.exists ? Team.fromSnapshot(snap) : null,
                                ))
                            .toList(),
                      )
                    : Stream.value([team]),
                initialData: List<Team?>.filled(teamIds.length, null),
                builder: (context, allTeamsSnapshot) {
                  final List<Team?> allTeams = allTeamsSnapshot.data ?? List.filled(teamIds.length, null);

                  return StreamBuilder<List<Plyr>>(
                    stream: _getTeamPlayersDataStream(team.players ?? [], team.startDate!, team.targetDate!),
                    builder: (context, playersSnapshot) {
                      if (playersSnapshot.connectionState == ConnectionState.waiting && !(playersSnapshot.hasData && playersSnapshot.data!.isNotEmpty)) {
                        return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
                      }
                      if (playersSnapshot.hasError) {
                        return Center(child: Text("Error loading players: ${playersSnapshot.error}."));
                      }

                      List<Plyr> currentPlayers = playersSnapshot.data ?? [];
                      int currentTeamTotalShots = currentPlayers.fold(0, (sum, p) => sum + (p.shots ?? 0));
                      int numActivePlayers = currentPlayers.isNotEmpty ? currentPlayers.length : 1;

                      // Null safety and fallback for team fields
                      final String safeName = team.name ?? 'Team';
                      final DateTime safeStartDate = team.startDate ?? DateTime.now();
                      final DateTime safeTargetDate = team.targetDate ?? DateTime.now().add(const Duration(days: 100));
                      final int safeGoalTotal = team.goalTotal ?? 0;
                      final String safeOwnerId = team.ownerId ?? '';
                      final bool safeOwnerParticipating = team.ownerParticipating ?? false;
                      final bool safePublic = team.public ?? false;
                      final List<String> safePlayers = team.players ?? [];
                      final Team safeTeam = Team(
                        safeName,
                        safeStartDate,
                        safeTargetDate,
                        safeGoalTotal,
                        safeOwnerId,
                        safeOwnerParticipating,
                        safePublic,
                        safePlayers,
                      )
                        ..id = team.id
                        ..reference = team.reference;

                      // Cache team for use in helper methods.
                      // Also publish to the global notifier so the nav bar edit
                      // button always reflects the team the user is viewing.
                      _currentTeam = safeTeam;
                      if (activeTeamIdNotifier.value != safeTeam.id) {
                        activeTeamIdNotifier.value = safeTeam.id;
                      }
                      final Color teamPrimaryColor = colorFromHex(team.primaryColor);

                      // ── Team switcher tabs (only visible with 2+ teams) ──────

                      final shotTexts = _calculateShotTexts(currentTeamTotalShots, safeTeam, numActivePlayers);
                      String displayShotsPerDayText = shotTexts['shotsPerDayText']!;
                      String displayShotsPerWeekText = shotTexts['shotsPerWeekText']!;

                      double totalShotsWidth = 0;
                      double totalShotsPercentage = 0;
                      if (safeGoalTotal > 0) {
                        totalShotsPercentage = (currentTeamTotalShots / safeGoalTotal.toDouble()) > 1 ? 1.0 : (currentTeamTotalShots / safeGoalTotal.toDouble());
                      }
                      totalShotsWidth = totalShotsPercentage * (MediaQuery.of(context).size.width - 60);
                      if (totalShotsWidth < 0) totalShotsWidth = 0;

                      return Column(
                        children: [
                          Expanded(
                              child: SingleChildScrollView(
                            physics: const ScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                // ── Pro subscription notice ────────────────────────
                                // Only visible when the user has MORE teams than the
                                // free plan allows (i.e. left over from a pro subscription)
                                // or when pro is about to expire and they'll be over the limit.
                                if (teamIds.length > kFreeTeamJoinLimit)
                                  _buildProStatusBanner(
                                    isPro: currentUserProfile.isPro ?? false,
                                    teamCount: teamIds.length,
                                  ),
                                // ── Team header banner ─────────────────────────────
                                GestureDetector(
                                  // Tap: instant sheet with light haptic.
                                  // Long press: animated press-in → spring-back → sheet.
                                  onTap: teamIds.length > 1
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          _showTeamSwitcherSheet(teamIds, allTeams, safeIndex);
                                        }
                                      : null,
                                  onLongPress: teamIds.length > 1
                                      ? () {
                                          HapticFeedback.mediumImpact();
                                          _cardPressController.forward().then((_) {
                                            if (!mounted) return;
                                            _cardPressController.reverse().then((_) {
                                              if (!mounted) return;
                                              HapticFeedback.lightImpact();
                                              _showTeamSwitcherSheet(teamIds, allTeams, safeIndex);
                                            });
                                          });
                                        }
                                      : null,
                                  child: AnimatedBuilder(
                                    animation: _cardScaleAnim,
                                    builder: (_, child) => Transform.scale(
                                      scale: _cardScaleAnim.value,
                                      child: child,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: colorFromHex(team.darkAccentColor, fallback: const Color(0xFF111111)).withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: teamPrimaryColor.withValues(alpha: 0.55), width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: teamPrimaryColor.withValues(alpha: 0.18),
                                            blurRadius: 18,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          buildTeamLogoWidget(
                                            context: context,
                                            logoAsset: team.logoAsset,
                                            primaryColorHex: team.primaryColor,
                                            darkAccentHex: team.darkAccentColor,
                                            lightAccentHex: team.lightAccentColor,
                                            size: 56,
                                            iconSize: 28,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: AutoSizeText(
                                              safeName,
                                              maxLines: 2,
                                              minFontSize: 12,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'NovecentoSans',
                                                fontSize: 22,
                                                color: colorFromHex(team.lightAccentColor, fallback: Colors.white),
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Switch team icon - only visible when on 2+ teams
                                          if (teamIds.length > 1) ...[
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () => _showTeamSwitcherSheet(teamIds, allTeams, safeIndex),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                child: Icon(
                                                  Icons.swap_horiz_rounded,
                                                  color: colorFromHex(team.lightAccentColor, fallback: Colors.white).withValues(alpha: 0.75),
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          // Team Activity button
                                          InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => context.push(AppRoutePaths.teamActivity, extra: team),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: teamPrimaryColor.withValues(alpha: 0.22),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: teamPrimaryColor, width: 1),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.dynamic_feed_rounded, color: colorFromHex(team.lightAccentColor, fallback: Colors.white), size: 16),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Activity'.toUpperCase(),
                                                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 13, color: colorFromHex(team.lightAccentColor, fallback: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.only(top: 5, bottom: 0),
                                  margin: const EdgeInsets.only(bottom: 10, top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text("Goal".toUpperCase(), style: TextStyle(color: teamPrimaryColor, fontSize: 26, fontFamily: 'NovecentoSans')),
                                      SizedBox(
                                        width: 150,
                                        child: AutoSizeTextField(
                                          controller: _targetDateController,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 1,
                                          maxFontSize: 14,
                                          decoration: InputDecoration(
                                            labelText: "${numberFormat.format(safeGoalTotal)} Shots By:".toLowerCase(),
                                            labelStyle: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontFamily: "NovecentoSans",
                                              fontSize: 22,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            contentPadding: const EdgeInsets.all(2),
                                          ),
                                          readOnly: true,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            child: GestureDetector(
                                              onTap: () => mounted ? setState(() => _showShotsPerDay = !_showShotsPerDay) : null,
                                              child: AutoSizeText(_showShotsPerDay ? displayShotsPerDayText : displayShotsPerWeekText, maxFontSize: 20, maxLines: 1, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: "NovecentoSans", fontSize: 20)),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => mounted ? setState(() => _showShotsPerDay = !_showShotsPerDay) : null,
                                            borderRadius: BorderRadius.circular(30),
                                            child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.swap_vert, size: 18)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Progress".toUpperCase(), style: TextStyle(color: teamPrimaryColor, fontSize: 22, fontFamily: 'NovecentoSans'))]),
                                const SizedBox(height: 5),
                                Column(children: [
                                  Container(
                                    width: (MediaQuery.of(context).size.width),
                                    margin: const EdgeInsets.symmetric(horizontal: 30),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: _teamAccentShade(context).withValues(alpha: 0.45)),
                                    clipBehavior: Clip.antiAlias,
                                    child: Row(children: [
                                      Tooltip(
                                        message: "${numberFormat.format(currentTeamTotalShots)} Shots".toLowerCase(),
                                        textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                        child: Container(height: 40, width: currentTeamTotalShots > 0 ? totalShotsWidth : 0, decoration: BoxDecoration(color: teamPrimaryColor)),
                                      ),
                                    ]),
                                  ),
                                  Container(
                                    width: (MediaQuery.of(context).size.width - 30),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                                    clipBehavior: Clip.antiAlias,
                                    child: Row(children: [
                                      Container(
                                        height: 40,
                                        width: totalShotsWidth < 35
                                            ? 50
                                            : totalShotsWidth > (MediaQuery.of(context).size.width - 110)
                                                ? totalShotsWidth - 175
                                                : totalShotsWidth,
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: AutoSizeText(numberFormat.format(currentTeamTotalShots), textAlign: TextAlign.right, maxFontSize: 18, maxLines: 1, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                                      ),
                                      Text(" / ${numberFormat.format(safeGoalTotal)}", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height: 5),
                                currentPlayers.isEmpty
                                    ? _buildNoPlayersOnTeamUI(team)
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(0),
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: currentPlayers.length,
                                        itemBuilder: (_, int index) {
                                          final Plyr p = currentPlayers[index];
                                          return _buildPlayerItem(p, index % 2 == 0, index + 1, team, isCurrentUserOwner);
                                        },
                                      ),
                                if (isCurrentUserOwner)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.picture_as_pdf_outlined),
                                        label: Text(
                                          'Export Leaderboard PDF'.toUpperCase(),
                                          style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 16),
                                        ),
                                        onPressed: () {
                                          final sorted = List<Plyr>.from(currentPlayers)..sort((a, b) => (b.shots ?? 0).compareTo(a.shots ?? 0));
                                          shareTeamLeaderboardPdf(
                                            context,
                                            safeTeam,
                                            sorted
                                                .map((p) => LeaderboardPlayer(
                                                      name: p.profile?.displayName ?? 'Unknown',
                                                      shots: p.shots ?? 0,
                                                    ))
                                                .toList(),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                if (isCurrentUserOwner) _buildEditTeamButton() else _buildLeaveTeamButton(team),
                                SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                              ],
                            ),
                          ))
                        ], // end Column + Expanded
                      ); // end Column
                    },
                  );
                }, // end allTeams builder
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoTeamUI() {
    return Align(
      alignment: const Alignment(0.0, -0.25),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 24.0, bottom: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 72,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 16),
            Text(
              "Team Challenge".toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 30,
                color: Theme.of(context).colorScheme.onPrimary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Join a team to compete and track shots together.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 40),
            // Create a Team card
            Card(
              elevation: 2,
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(AppRoutePaths.createTeam),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create a Team".toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Set a goal and invite players",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            // Join a Team card
            Card(
              elevation: 2,
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(AppRoutePaths.joinTeam),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.onPrimary, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Join a Team".toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Scan a QR code or enter a team code",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRemovedOrNotFoundUI(String? teamName, DocumentReference? userProfileRef, String teamIdToRemove) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            teamName != null ? "You have been removed from team \"$teamName\" or the team no longer exists.".toUpperCase() : "The team you were part of no longer exists or your access was removed.".toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 22, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 20),
          Text("You are free to join or create a new team.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () async {
              if (userProfileRef != null) {
                // Remove only this specific team from the list, keeping all others.
                try {
                  final u = await userProfileRef.get();
                  if (u.exists) {
                    final UserProfile profile = UserProfile.fromSnapshot(u);
                    profile.teamIds.remove(teamIdToRemove);
                    await userProfileRef.update({
                      'team_ids': profile.teamIds,
                      'team_id': profile.teamIds.isNotEmpty ? profile.teamIds.first : null,
                    });
                    // Snap the selected index back to a valid position
                    if (mounted) {
                      final clamped = _selectedTeamIndex.clamp(0, (profile.teamIds.length - 1).clamp(0, 9999));
                      setState(() => _selectedTeamIndex = clamped);
                      _saveTeamIndex(clamped);
                    }
                  }
                } catch (_) {}
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorFromHex(_currentTeam?.primaryColor),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text("Ok".toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlayersOnTeamUI(Team teamData) {
    // Removed unused local variables for auth/firestore
    return Column(children: [
      Container(margin: const EdgeInsets.only(top: 40), child: Text("No Players on the Team (yet!)".toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary))),
      Container(
          margin: const EdgeInsets.only(top: 15),
          child: Center(
              child: Ink(
                  decoration: ShapeDecoration(color: Theme.of(context).cardTheme.color, shape: const CircleBorder()),
                  child: IconButton(
                      iconSize: 40,
                      icon: Icon(Icons.share, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () async {
                        bool teamQrWasDisplayed = await displayTeamQRCodeDialog(context, teamData.id, teamData.name, team: teamData);

                        if (!teamQrWasDisplayed) {
                          if (!mounted) return;

                          final barcodeScanRes = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BarcodeScannerSimple(title: "Scan Team QR Code"),
                            ),
                          );

                          if (barcodeScanRes != null && barcodeScanRes.toString().isNotEmpty) {
                            // Use Provider to get auth/firestore
                            final auth = Provider.of<FirebaseAuth>(context, listen: false);
                            final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                            final isPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
                            bool success = await joinTeam(barcodeScanRes.toString(), auth, firestore, isProUser: isPro);

                            if (success) {
                              Fluttertoast.showToast(msg: "Successfully joined new team!");
                            } else {
                              // Check if failure was due to the free-tier join cap.
                              String failMsg = "Failed to join team using scanned code.";
                              if (!isPro) {
                                try {
                                  final uDoc = await firestore.collection('users').doc(auth.currentUser?.uid).get();
                                  final profile = UserProfile.fromSnapshot(uDoc);
                                  if (profile.teamIds.length >= kFreeTeamJoinLimit) {
                                    failMsg = "you've reached the $kFreeTeamJoinLimit team limit on the free plan. upgrade to pro to join more teams.";
                                  }
                                } catch (_) {}
                              }
                              Fluttertoast.showToast(msg: failMsg);
                            }
                          }
                        }
                      })))),
    ]);
  }

  Widget _buildPlayerItem(Plyr plyr, bool bg, int place, Team currentTeam, bool isCurrentUserOwner) {
    final String playerUid = plyr.profile?.reference?.id ?? "";
    final bool isDeletedUser = plyr.profile?.displayName == "Deleted User";
    // Removed unused local variables for firestore/auth
    return GestureDetector(
      onTap: isDeletedUser
          ? null
          : () {
              Feedback.forTap(context);
              if (playerUid.isNotEmpty) {
                context.push(AppRoutePaths.playerPathFor(playerUid));
              }
            },
      child: (isCurrentUserOwner && user?.uid != playerUid && playerUid.isNotEmpty)
          ? Dismissible(
              key: ValueKey(playerUid),
              onDismissed: (direction) async {
                // Use Provider to get firestore
                final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                await removePlayerFromTeam(currentTeam.id!, playerUid, firestore).then((deleted) {
                  if (deleted) {
                    Fluttertoast.showToast(msg: '${plyr.profile?.displayName ?? "Player"} removed');
                  } else {
                    Fluttertoast.showToast(msg: 'Failed to remove ${plyr.profile?.displayName ?? "player"}');
                  }
                });
              },
              confirmDismiss: (DismissDirection direction) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: Text("Remove Player?".toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 24)),
                        content: Text("Are you sure you want to remove ${plyr.profile?.displayName ?? 'this player'} from your team?", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel".toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).colorScheme.onPrimary))),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Delete".toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', color: colorFromHex(_currentTeam?.primaryColor)))),
                        ],
                      ),
                    ) ??
                    false;
              },
              background: Container(
                  color: colorFromHex(_currentTeam?.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Delete".toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: Colors.white)), const Icon(Icons.delete, size: 16, color: Colors.white)])),
              child: _buildPlayerListItemContent(plyr, bg, place, isDeletedUser),
            )
          : _buildPlayerListItemContent(plyr, bg, place, isDeletedUser),
    );
  }

  /// Returns the team's appropriate accent shade for background shading.
  /// Uses darkAccentColor in dark mode, lightAccentColor in light mode.
  /// Falls back to the theme card color when the accent is not configured.
  Color _teamAccentShade(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hex = isDark ? _currentTeam?.darkAccentColor : _currentTeam?.lightAccentColor;
    if (hex != null) return colorFromHex(hex);
    return Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
  }

  Widget _buildEditTeamButton() {
    // Simple placeholder button for editing team
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: TextButton(
        onPressed: () {
          context.push(AppRoutePaths.editTeam, extra: _currentTeam!.id);
        },
        style: TextButton.styleFrom(foregroundColor: colorFromHex(_currentTeam?.primaryColor), backgroundColor: _teamAccentShade(context), shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0)))),
        child: FittedBox(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center, children: [Text("Edit Team".toUpperCase(), style: TextStyle(color: colorFromHex(_currentTeam?.primaryColor), fontFamily: 'NovecentoSans', fontSize: 24)), Padding(padding: const EdgeInsets.only(top: 3, left: 4), child: Icon(Icons.edit, color: colorFromHex(_currentTeam?.primaryColor), size: 24))])),
      ),
    );
  }

  Widget _buildPlayerListItemContent(Plyr plyr, bool bg, int place, bool isDeletedUser) {
    final bool isProForDisplay = plyr.profile?.isPro == true;
    // Raw photo URL from profile (can be network URL, asset path, or an unintended file URI)
    final String? rawPhotoUrl = plyr.profile?.photoUrl;
    String? photoUrl = rawPhotoUrl;
    // Sanitize: if the value starts with file:/// but actually points to an asset path we strip the schema
    if (photoUrl != null && photoUrl.startsWith('file:///')) {
      // Remove the scheme
      photoUrl = photoUrl.substring('file:///'.length);
      // If a leading slash remains (e.g. /assets/...), strip it so AssetImage can resolve it
      if (photoUrl.startsWith('/')) {
        photoUrl = photoUrl.substring(1);
      }
    }
    final String displayName = plyr.profile?.displayName ?? "Player";
    Widget? badgeWidget;
    double avatarRadius = 32;
    double badgeFontSize = 14;
    double badgePaddingH = 8;
    double badgePaddingV = 5;
    Color badgeColor;
    Color badgeTextColor = Colors.white;
    List<Shadow> badgeTextShadows = [
      Shadow(
        offset: Offset(0, 1),
        blurRadius: 2,
        color: Colors.black.withOpacity(0.45),
      ),
    ];
    if (place == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      badgeTextColor = Colors.black;
      badgeTextShadows = [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.white.withOpacity(0.7),
        ),
      ];
    } else if (place == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      badgeTextColor = Colors.black87;
      badgeTextShadows = [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.white.withOpacity(0.7),
        ),
      ];
    } else if (place == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      badgeTextColor = Colors.white;
      badgeTextShadows = [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.black.withOpacity(0.7),
        ),
      ];
    } else {
      badgeColor = (user?.uid == plyr.profile?.reference?.id) ? colorFromHex(_currentTeam?.primaryColor).withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
    }
    badgeWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: badgePaddingH, vertical: badgePaddingV),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        place.toString(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontWeight: FontWeight.bold,
          fontSize: badgeFontSize,
          color: badgeTextColor,
          shadows: badgeTextShadows,
        ),
      ),
    );
    // Decide how to render the avatar image
    ImageProvider? networkAvatarImage;
    String? assetAvatarPath;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        networkAvatarImage = NetworkImage(photoUrl);
      } else {
        // Asset path (e.g. assets/images/avatars/...)
        assetAvatarPath = photoUrl;
      }
    }

    return Opacity(
      opacity: isDeletedUser ? 0.5 : 1.0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: bg ? _teamAccentShade(context).withValues(alpha: 0.22) : Colors.transparent,
        leading: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            UserAvatarCrPopover(
              userId: plyr.profile?.reference?.id ?? '',
              menuColor: Theme.of(context).colorScheme.primary,
              showAccomplishment: isProForDisplay,
              showProFallback: isProForDisplay,
              extraActions: isDeletedUser || (plyr.profile?.reference?.id ?? '').isEmpty || (plyr.profile?.reference?.id == user?.uid)
                  ? const <UserAvatarPopoverAction>[]
                  : [
                      UserAvatarPopoverAction(
                        label: 'Compare Stats',
                        icon: Icons.compare_arrows_rounded,
                        onTap: () {
                          Feedback.forTap(context);
                          context.push(AppRoutePaths.compareStatsPathFor(plyr.profile!.reference!.id));
                        },
                      ),
                    ],
              onViewProfile: isDeletedUser || (plyr.profile?.reference?.id ?? '').isEmpty
                  ? null
                  : () {
                      Feedback.forTap(context);
                      context.push(AppRoutePaths.playerPathFor(plyr.profile?.reference?.id ?? ''));
                    },
              onViewCrProgress: isDeletedUser || (plyr.profile?.reference?.id ?? '').isEmpty
                  ? null
                  : () {
                      Feedback.forTap(context);
                      context.push(AppRoutePaths.playerChallengerRoadPathFor(plyr.profile!.reference!.id));
                    },
              onUnlockChallengerRoad: () {
                Feedback.forTap(context);
                context.go(AppRoutePaths.app);
                openChallengerRoadSignal.value++;
              },
              child: SizedBox(
                width: avatarRadius * 2,
                height: avatarRadius * 2,
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  backgroundImage: networkAvatarImage,
                  child: assetAvatarPath != null
                      ? ClipOval(
                          child: Image(
                            image: AssetImage(assetAvatarPath),
                            width: avatarRadius * 2,
                            height: avatarRadius * 2,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (networkAvatarImage == null)
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 28, color: colorFromHex(_currentTeam?.primaryColor)),
                            )
                          : null,
                ),
              ),
            ),
            if (!isDeletedUser && (plyr.profile?.reference?.id ?? '').isNotEmpty)
              Positioned(
                bottom: -2,
                right: -3,
                child: CrAvatarTrophyStream(
                  userId: plyr.profile!.reference!.id,
                  size: 18,
                  showProFallback: isProForDisplay,
                ),
              ),
            Positioned(
              bottom: -4,
              right: -4,
              child: badgeWidget,
            ),
          ],
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 20,
            color: isDeletedUser
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                : (plyr.profile?.reference?.id == user?.uid)
                    ? colorFromHex(_currentTeam?.primaryColor)
                    : Theme.of(context).colorScheme.onSurface,
            fontWeight: (plyr.profile?.reference?.id == user?.uid) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: SizedBox(
          height: 60,
          child: Stack(
            children: [
              Text(
                numberFormat.format(plyr.shots ?? 0), // Format with commas
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 26, // Large shot count
                  fontWeight: FontWeight.bold,
                  color: isDeletedUser ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4) : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Positioned(
                top: 30,
                right: 0,
                child: Text(
                  'Shots'.toLowerCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveTeamButton(Team currentTeam) {
    final isOwner = currentTeam.ownerId == (user?.uid ?? '');
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: TextButton(
        onPressed: () {
          if (isOwner) {
            _showOwnerLeaveSheet(currentTeam);
          } else {
            dialog(
                context,
                ConfirmDialog("Leave team ${currentTeam.name}?".toLowerCase(), Text("Are you sure you want to leave this team?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)), "Cancel", () => Navigator.of(context).pop(), "Leave", () async {
                  Navigator.of(context).pop();
                  final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                  await removePlayerFromTeam(currentTeam.id!, user?.uid ?? '', firestore).then((r) {
                    if (r) {
                      Fluttertoast.showToast(msg: "You left team ${currentTeam.name}!".toLowerCase());
                      if (mounted) {
                        goToAppSection(
                          context,
                          AppSection.community,
                          communitySection: CommunitySection.team,
                        );
                      }
                    } else {
                      Fluttertoast.showToast(msg: "Failed to leave team :(".toLowerCase());
                    }
                  });
                }));
          }
        },
        style: TextButton.styleFrom(foregroundColor: colorFromHex(_currentTeam?.primaryColor), backgroundColor: _teamAccentShade(context), shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0)))),
        child: FittedBox(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Leave Team".toUpperCase(), style: TextStyle(color: colorFromHex(_currentTeam?.primaryColor), fontFamily: 'NovecentoSans', fontSize: 24)), Padding(padding: const EdgeInsets.only(top: 3, left: 4), child: Icon(Icons.exit_to_app_rounded, color: colorFromHex(_currentTeam?.primaryColor), size: 24))])),
      ),
    );
  }

  /// Bottom sheet shown when the team owner tries to leave.
  /// They must either transfer ownership to another member or delete the team.
  void _showOwnerLeaveSheet(Team currentTeam) {
    final otherMembers = (currentTeam.players ?? []).where((uid) => uid != (user?.uid ?? '')).toList();
    final teamPrimary = colorFromHex(currentTeam.primaryColor);
    final teamDark = colorFromHex(currentTeam.darkAccentColor, fallback: const Color(0xFF111111));
    final teamLight = colorFromHex(currentTeam.lightAccentColor, fallback: Colors.white);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Team identity mini-banner ────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: teamDark.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: teamPrimary.withValues(alpha: 0.55), width: 1.5),
                  boxShadow: [BoxShadow(color: teamPrimary.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    buildTeamLogoWidget(
                      context: sheetCtx,
                      logoAsset: currentTeam.logoAsset,
                      primaryColorHex: currentTeam.primaryColor,
                      darkAccentHex: currentTeam.darkAccentColor,
                      lightAccentHex: currentTeam.lightAccentColor,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (currentTeam.name ?? '').toUpperCase(),
                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: teamLight, height: 1.1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'you are the owner'.toUpperCase(),
                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 11, color: teamPrimary, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Instruction copy ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Text(
                  'Before leaving, choose what happens to this team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Theme.of(sheetCtx).colorScheme.onPrimary.withValues(alpha: 0.55)),
                ),
              ),
              // ── Transfer ownership ────────────────────────────────────
              if (otherMembers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(children: [
                    Container(width: 3, height: 16, decoration: BoxDecoration(color: teamPrimary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text('Transfer Ownership'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Theme.of(sheetCtx).colorScheme.onPrimary.withValues(alpha: 0.5), letterSpacing: 0.8)),
                  ]),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: otherMembers.length,
                  itemBuilder: (_, i) {
                    final memberUid = otherMembers[i];
                    return FutureBuilder<DocumentSnapshot>(
                      future: Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(memberUid).get(),
                      builder: (_, snap) {
                        String displayName = '...';
                        if (snap.hasData && snap.data!.exists) {
                          final profile = UserProfile.fromSnapshot(snap.data! as DocumentSnapshot<Map<String, dynamic>>);
                          displayName = profile.displayName ?? profile.notifName;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              dialog(
                                context,
                                ConfirmDialog(
                                  'Transfer ownership?'.toLowerCase(),
                                  Text('Make $displayName the new owner of ${currentTeam.name}? You will remain a member.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                  'Cancel',
                                  () => Navigator.of(context).pop(),
                                  'Transfer',
                                  () async {
                                    Navigator.of(context).pop();
                                    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                                    final ok = await transferTeamOwnership(currentTeam.id!, memberUid, firestore);
                                    Fluttertoast.showToast(
                                      msg: ok ? 'ownership transferred to $displayName.' : 'transfer failed. please try again.',
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: teamDark.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: teamPrimary.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: teamPrimary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: teamPrimary.withValues(alpha: 0.4), width: 1),
                                    ),
                                    child: Icon(Icons.person_rounded, color: teamPrimary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(displayName, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 17, color: teamLight)),
                                        Text('becomes owner · you stay as member', style: TextStyle(fontSize: 11, color: teamLight.withValues(alpha: 0.45))),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: teamPrimary.withValues(alpha: 0.6), size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Divider(color: Theme.of(sheetCtx).colorScheme.onPrimary.withValues(alpha: 0.08), height: 1, indent: 16, endIndent: 16),
                const SizedBox(height: 16),
              ],
              // ── Delete team ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(children: [
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Danger Zone'.toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: Colors.red.shade400.withValues(alpha: 0.7), letterSpacing: 0.8)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    dialog(
                      context,
                      ConfirmDialog(
                        'Delete ${currentTeam.name}?'.toLowerCase(),
                        Text('This permanently removes the team and all its data for every member. This cannot be undone.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        'Cancel',
                        () => Navigator.of(context).pop(),
                        'Delete',
                        () async {
                          Navigator.of(context).pop();
                          final auth = Provider.of<FirebaseAuth>(context, listen: false);
                          final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                          final ok = await deleteTeam(currentTeam.id!, auth, firestore);
                          if (ok && mounted) {
                            Fluttertoast.showToast(msg: 'team deleted.');
                            goToAppSection(context, AppSection.community, communitySection: CommunitySection.team);
                          } else if (!ok) {
                            Fluttertoast.showToast(msg: 'failed to delete team.');
                          }
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.45), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Delete Team', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 17, color: Colors.red.shade300)),
                              Text('permanently removes team for all members', style: TextStyle(fontSize: 11, color: Colors.red.shade300.withValues(alpha: 0.55))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.red.shade400.withValues(alpha: 0.6), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + 24),
            ],
          ),
        );
      },
    );
  }
}
