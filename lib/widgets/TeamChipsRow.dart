// ignore_for_file: file_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';

/// Compact team membership indicator for profile headers.
///
/// - **1 team**: a single pill chip showing the logo + name.
/// - **2+ teams**: an overlapping bubble stack with a "N teams ▾" label.
///   Tapping toggles an animated expansion that reveals full named chips.
class TeamChipsRow extends StatefulWidget {
  const TeamChipsRow({super.key, required this.teamIds});

  final List<String> teamIds;

  @override
  State<TeamChipsRow> createState() => _TeamChipsRowState();
}

class _TeamChipsRowState extends State<TeamChipsRow> {
  List<Team> _teams = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _fetchTeams(widget.teamIds);
  }

  @override
  void didUpdateWidget(TeamChipsRow old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.teamIds, widget.teamIds)) {
      _expanded = false;
      _fetchTeams(widget.teamIds);
    }
  }

  Future<void> _fetchTeams(List<String> ids) async {
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _teams = [];
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    final snaps = await Future.wait(
      ids.map((id) => FirebaseFirestore.instance.collection('teams').doc(id).get()),
    );
    if (!mounted) return;
    setState(() {
      _teams = snaps.where((d) => d.exists).map((d) => Team.fromSnapshot(d)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _teams.isEmpty) return const SizedBox.shrink();

    // Single team: just the pill chip, no tap needed.
    // Align converts any tight-stretch constraints from the parent into loose
    // ones, so the chip sizes to its content rather than filling full width.
    if (_teams.length == 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _TeamChip(team: _teams.first),
      );
    }

    // Multiple teams: collapsed bubble stack + expand-on-tap.
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Collapsed summary row ──────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BubbleStack(teams: _teams),
              const SizedBox(width: 6),
              Text(
                '${_teams.length} teams',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'NovecentoSans',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
        // ── Expanded chip list ─────────────────────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              children: _teams.map((t) => _TeamChip(team: t)).toList(),
            ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

// ── Overlapping logo bubble stack ─────────────────────────────────────────────

class _BubbleStack extends StatelessWidget {
  const _BubbleStack({required this.teams});

  final List<Team> teams;

  static const double _size = 20;
  static const double _step = 13; // visible stride (20 - 7px overlap)

  @override
  Widget build(BuildContext context) {
    final totalWidth = _size + (teams.length - 1) * _step;
    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < teams.length; i++)
            Positioned(
              left: i * _step,
              child: _bubble(context, teams[i]),
            ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, Team team) {
    final primaryColor = colorFromHex(team.primaryColor);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
        // Thin surface-coloured border separates overlapping bubbles cleanly.
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.30),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: team.logoAsset != null
          ? ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  resolveTeamLogoPath(team.logoAsset!),
                  fit: BoxFit.contain,
                ),
              ),
            )
          : Icon(Icons.group_rounded, color: Colors.white.withValues(alpha: 0.9), size: _size * 0.54),
    );
  }
}

// ── Individual team chip ──────────────────────────────────────────────────────

class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final primaryColor = colorFromHex(team.primaryColor);
    final darkColor = colorFromHex(team.darkAccentColor, fallback: const Color(0xFF1C1C2A));
    final lightColor = colorFromHex(team.lightAccentColor, fallback: Colors.white);

    return Container(
      height: 24,
      padding: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: darkColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTeamLogoWidget(
            context: context,
            logoAsset: team.logoAsset,
            primaryColorHex: team.primaryColor,
            darkAccentHex: team.darkAccentColor,
            lightAccentHex: team.lightAccentColor,
            size: 24,
            iconSize: 11,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              team.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'NovecentoSans',
                color: lightColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
