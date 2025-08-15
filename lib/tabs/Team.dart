// ignore_for_file: constant_identifier_names

import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; // For QRCodeDialog
import 'package:rxdart/rxdart.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:go_router/go_router.dart';

const TEAM_HEADER_HEIGHT = 65.0;

// QRCodeDialog Class (Included directly in this file for simplicity)
class QRCodeDialog extends StatelessWidget {
  final String title;
  final String data;
  final String? message;

  const QRCodeDialog({
    super.key,
    required this.title,
    required this.data,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          color: Theme.of(context).primaryColor,
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
          SizedBox(
            width: 200,
            height: 200,
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white, // Ensure QR is visible in dark mode
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Theme.of(context).colorScheme.onSurface,
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
Future<bool> displayTeamQRCodeDialog(BuildContext context, String? teamId, String? teamName) async {
  if (teamId != null && teamId.isNotEmpty && teamName != null && teamName.isNotEmpty) {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => QRCodeDialog(
        title: "Team QR Code",
        data: teamId,
        message: "Have new players scan this code to join '$teamName'.",
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

  @override
  void initState() {
    super.initState();
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
      // Corrected UserProfile placeholder
      return UserProfile("Loading...", "Loading...", null, null, null, null, null);
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
      // Fallback Plyr object
      // Corrected UserProfile placeholder
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
      var validPlyrs = listOfPlyrs.where((p) => p.profile?.displayName != "Loading..." && p.profile?.displayName != "Error").toList();
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
          final String? teamId = currentUserProfile.teamId;

          if (teamId == null) {
            return _buildNoTeamUI();
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getTeamStream(teamId),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
              }
              if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                return _buildTeamRemovedOrNotFoundUI(null, currentUserProfile.reference);
              }

              Team team = Team.fromSnapshot(teamSnapshot.data!);
              bool isCurrentUserOwner = team.ownerId == user?.uid;
              _targetDateController.text = DateFormat('MMMM d, y').format(team.targetDate ?? DateTime.now().add(const Duration(days: 100)));

              if (!(team.players?.contains(user?.uid) ?? false)) {
                return _buildTeamRemovedOrNotFoundUI(team.name, currentUserProfile.reference);
              }

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
                  );

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

                  return SingleChildScrollView(
                    physics: const ScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(top: 5, bottom: 0),
                          margin: const EdgeInsets.only(bottom: 10, top: 15),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("Goal".toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 26, fontFamily: 'NovecentoSans')),
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
                                      child: AutoSizeText(_showShotsPerDay ? displayShotsPerDayText : displayShotsPerWeekText,
                                          maxFontSize: 20, maxLines: 1, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: "NovecentoSans", fontSize: 20)),
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
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Text("Progress".toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 22, fontFamily: 'NovecentoSans'))]),
                        const SizedBox(height: 5),
                        Column(children: [
                          Container(
                            width: (MediaQuery.of(context).size.width),
                            margin: const EdgeInsets.symmetric(horizontal: 30),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Theme.of(context).cardTheme.color),
                            clipBehavior: Clip.antiAlias,
                            child: Row(children: [
                              Tooltip(
                                message: "${numberFormat.format(currentTeamTotalShots)} Shots".toLowerCase(),
                                textStyle: TextStyle(fontFamily: "NovecentoSans", fontSize: 20, color: Theme.of(context).colorScheme.onPrimary),
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                                child: Container(height: 40, width: currentTeamTotalShots > 0 ? totalShotsWidth : 0, decoration: BoxDecoration(color: Theme.of(context).primaryColor)),
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
                                child: AutoSizeText(numberFormat.format(currentTeamTotalShots),
                                    textAlign: TextAlign.right, maxFontSize: 18, maxLines: 1, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
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
                        if (isCurrentUserOwner) _buildEditTeamButton() else _buildLeaveTeamButton(team),
                        const SizedBox(height: 56),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoTeamUI() {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Tap + to create a team".toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Ink(
                decoration: ShapeDecoration(color: Theme.of(context).cardTheme.color, shape: const CircleBorder()),
                child: IconButton(
                    iconSize: 40,
                    icon: Icon(Icons.add, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                    onPressed: () {
                      context.push('/create-team');
                    })),
          ),
          const Divider(height: 30),
          Text("Or join an existing team".toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary)),
          Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child: MaterialButton(
                color: Theme.of(context).cardTheme.color,
                child: Text("Join Team".toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary)),
                onPressed: () {
                  context.push('/join-team');
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRemovedOrNotFoundUI(String? teamName, DocumentReference? userProfileRef) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            teamName != null ? "You have been removed from team \"$teamName\" or the team no longer exists.".toUpperCase() : "The team you were part of no longer exists or your access was removed.".toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 22),
          ),
          const SizedBox(height: 20),
          Text("You are free to join or create a new team.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () async {
              if (userProfileRef != null) {
                await userProfileRef.update({'team_id': null}).catchError((e) {
                  // print("Error clearing team_id: $e");
                });
              }
            },
            child: Text("Ok".toUpperCase()),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlayersOnTeamUI(Team teamData) {
    // Removed unused local variables for auth/firestore
    return Column(children: [
      Container(
          margin: const EdgeInsets.only(top: 40),
          child: Text("No Players on the Team (yet!)".toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).colorScheme.onPrimary))),
      Container(
          margin: const EdgeInsets.only(top: 15),
          child: Center(
              child: Ink(
                  decoration: ShapeDecoration(color: Theme.of(context).cardTheme.color, shape: const CircleBorder()),
                  child: IconButton(
                      iconSize: 40,
                      icon: Icon(Icons.share, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () async {
                        bool teamQrWasDisplayed = await displayTeamQRCodeDialog(context, teamData.id, teamData.name);

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
                            bool success = await joinTeam(barcodeScanRes.toString(), auth, firestore);

                            if (success) {
                              Fluttertoast.showToast(msg: "Successfully joined new team!");
                            } else {
                              Fluttertoast.showToast(msg: "Failed to join team using scanned code.");
                            }
                          }
                        }
                      })))),
    ]);
  }

  Widget _buildPlayerItem(Plyr plyr, bool bg, int place, Team currentTeam, bool isCurrentUserOwner) {
    final String playerUid = plyr.profile?.reference?.id ?? "";
    // Removed unused local variables for firestore/auth
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        if (playerUid.isNotEmpty) {
          context.push('/player/$playerUid');
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
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Delete".toUpperCase(), style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor))),
                        ],
                      ),
                    ) ??
                    false;
              },
              background: Container(
                  color: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text("Delete".toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: Colors.white)), const Icon(Icons.delete, size: 16, color: Colors.white)])),
              child: _buildPlayerListItemContent(plyr, bg, place),
            )
          : _buildPlayerListItemContent(plyr, bg, place),
    );
  }

  Widget _buildEditTeamButton() {
    // Simple placeholder button for editing team
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: TextButton(
        onPressed: () {
          context.push('/edit-team');
        },
        style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).cardTheme.color, backgroundColor: Theme.of(context).cardTheme.color, shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0)))),
        child: FittedBox(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Edit Team".toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontFamily: 'NovecentoSans', fontSize: 24)),
          Padding(padding: const EdgeInsets.only(top: 3, left: 4), child: Icon(Icons.edit, color: Theme.of(context).primaryColor, size: 24))
        ])),
      ),
    );
  }

  Widget _buildPlayerListItemContent(Plyr plyr, bool bg, int place) {
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
      badgeColor = (user?.uid == plyr.profile?.reference?.id) ? Theme.of(context).primaryColor.withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
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
    // Decide which ImageProvider to use
    ImageProvider? avatarImage;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        // Network image
        avatarImage = NetworkImage(photoUrl);
      } else if (photoUrl.startsWith('assets/')) {
        // Asset image in bundled assets
        avatarImage = AssetImage(photoUrl);
      } else {
        // Fallback: if it's some other non-empty string treat as asset path attempt
        avatarImage = AssetImage(photoUrl);
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
      leading: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            backgroundImage: avatarImage,
            child: (avatarImage == null)
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 28, color: Theme.of(context).primaryColor),
                  )
                : null,
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
          color: (plyr.profile?.reference?.id == user?.uid) ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
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
    );
  }

  Widget _buildLeaveTeamButton(Team currentTeam) {
    // Removed unused local variables for auth/firestore
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: TextButton(
        onPressed: () {
          dialog(
              context,
              ConfirmDialog("Leave team ${currentTeam.name}?".toLowerCase(), Text("Are you sure you want to leave this team?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)), "Cancel",
                  () => Navigator.of(context).pop(), "Leave", () async {
                Navigator.of(context).pop();
                // Use Provider to get firestore
                final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
                await removePlayerFromTeam(currentTeam.id!, user?.uid ?? '', firestore).then((r) {
                  if (r) {
                    Fluttertoast.showToast(msg: "You left team ${currentTeam.name}!".toLowerCase());
                    if (mounted) {
                      context.go('/app?tab=team');
                    }
                  } else {
                    Fluttertoast.showToast(msg: "Failed to leave team :(".toLowerCase());
                  }
                });
              }));
        },
        style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).cardTheme.color, backgroundColor: Theme.of(context).cardTheme.color, shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0)))),
        child: FittedBox(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Leave Team".toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontFamily: 'NovecentoSans', fontSize: 24)),
          Padding(padding: const EdgeInsets.only(top: 3, left: 4), child: Icon(Icons.exit_to_app_rounded, color: Theme.of(context).primaryColor, size: 24))
        ])),
      ),
    );
  }
}
