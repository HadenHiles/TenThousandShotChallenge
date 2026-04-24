// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

// ─── Logo catalog ────────────────────────────────────────────────────────────

class TeamLogo {
  final String key; // matches filename in assets/images/avatars/teams/
  final String name;
  final String mascot; // shown as subtitle hint
  const TeamLogo(this.key, this.name, this.mascot);
  String get assetPath => 'assets/images/avatars/teams/$key.png';
}

const List<TeamLogo> kTeamLogos = [
  TeamLogo('blackhawks', 'Blackhawks', 'Hawk'),
  TeamLogo('ducks', 'Ducks', 'Duck'),
  TeamLogo('penguins', 'Penguins', 'Penguin'),
  TeamLogo('canucks', 'Canucks', 'Orca'),
  TeamLogo('capitals', 'Capitals', 'Eagle'),
  TeamLogo('coyotes', 'Coyotes', 'Coyote'),
  TeamLogo('wild', 'Wild', 'Forest animal'),
  TeamLogo('predators', 'Predators', 'Sabertooth cat'),
  TeamLogo('sharks', 'Sharks', 'Shark'),
  TeamLogo('kraken', 'Kraken', 'Sea monster'),
  TeamLogo('panthers', 'Panthers', 'Panther'),
  TeamLogo('bruins', 'Bruins', 'Bear'),
  TeamLogo('hurricanes', 'Hurricanes', 'Hurricane'),
  TeamLogo('lightning', 'Lightning', 'Lightning bolt'),
  TeamLogo('flames', 'Flames', 'Flame'),
  TeamLogo('avalanche', 'Avalanche', 'Mountain'),
  TeamLogo('stars', 'Stars', 'Star'),
  TeamLogo('golden-knights', 'Golden Knights', 'Knight'),
  TeamLogo('kings-1', 'Kings', 'Crown'),
  TeamLogo('senators', 'Senators', 'Roman senator'),
  TeamLogo('rangers', 'Rangers', 'Shield'),
  TeamLogo('maple-leafs', 'Maple Leafs', 'Maple leaf'),
  TeamLogo('oilers', 'Oilers', 'Oil drop'),
  TeamLogo('flyers', 'Flyers', 'Wing'),
  TeamLogo('red-wings', 'Red Wings', 'Winged wheel'),
  TeamLogo('devils', 'Devils', 'Devil'),
  TeamLogo('blue-jackets', 'Blue Jackets', 'Cannon'),
  TeamLogo('blues', 'Blues', 'Music note'),
  TeamLogo('canadiens', 'Canadiens', 'Classic C'),
  TeamLogo('islanders', 'Islanders', 'Islander'),
  TeamLogo('jets', 'Jets', 'Jet'),
  TeamLogo('sabres', 'Sabres', 'Crossed sabres'),
];

// ─── Color palettes ───────────────────────────────────────────────────────────

/// Primary team colors — reds, blues, greens, golds, purples, black
const List<String> kPrimaryColors = [
  '#CC3333', '#C8102E', '#B22222', '#E63946', // Reds
  '#F47920', '#FF6B2C', '#D46B08', // Oranges
  '#FCB514', '#FFD700', '#B5985A', '#CFA23A', // Golds / Yellows
  '#006343', '#00843D', '#2D6A4F', '#1F7A4E', // Greens
  '#003E7E', '#005EBD', '#041E42', '#0038A8', // Blues
  '#4B9AC7', '#1F5EA8', '#00205B', // More blues
  '#5C2D91', '#702082', // Purples
  '#111111', // Black
];

/// Dark accent colors — dark neutrals and tinted darks
const List<String> kDarkAccentColors = [
  '#111111',
  '#1A1A1A',
  '#2B2B2B',
  '#3D3D3D',
  '#1A2744',
  '#1B3A2D',
  '#1E0A26',
  '#1C0A0A',
  '#1A2030',
  '#0D1B2A',
];

/// Light accent colors — whites, greys, creams, light tints
const List<String> kLightAccentColors = [
  '#FFFFFF',
  '#F5F5F5',
  '#E8E8E8',
  '#D4D4D4',
  '#C0C0C0',
  '#F5F0E8',
  '#E8F0F5',
  '#FFF9E6',
  '#E0E5EB',
  '#D9E4EC',
];

// ─── TeamIdentityPicker widget ────────────────────────────────────────────────

/// A card-based picker for team logo, primary color, dark accent, and light
/// accent. Manages its own state internally; reports changes via callbacks.
class TeamIdentityPicker extends StatefulWidget {
  final String? initialLogoAsset;
  final String initialPrimaryColor;
  final String initialDarkAccent;
  final String initialLightAccent;
  final ValueChanged<String?> onLogoChanged;
  final ValueChanged<String> onPrimaryColorChanged;
  final ValueChanged<String> onDarkAccentChanged;
  final ValueChanged<String> onLightAccentChanged;

  const TeamIdentityPicker({
    super.key,
    this.initialLogoAsset,
    this.initialPrimaryColor = '#CC3333',
    this.initialDarkAccent = '#111111',
    this.initialLightAccent = '#FFFFFF',
    required this.onLogoChanged,
    required this.onPrimaryColorChanged,
    required this.onDarkAccentChanged,
    required this.onLightAccentChanged,
  });

  @override
  State<TeamIdentityPicker> createState() => _TeamIdentityPickerState();
}

class _TeamIdentityPickerState extends State<TeamIdentityPicker> {
  String? _logoAsset;
  late String _primaryColor;
  late String _darkAccent;
  late String _lightAccent;

  @override
  void initState() {
    super.initState();
    _logoAsset = widget.initialLogoAsset;
    _primaryColor = widget.initialPrimaryColor;
    _darkAccent = widget.initialDarkAccent;
    _lightAccent = widget.initialLightAccent;
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 12,
          letterSpacing: 0.5,
          color: (preferences?.darkMode ?? false) ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
        ),
      ),
    );
  }

  // ── Logo section ─────────────────────────────────────────────────────────
  Widget _buildLogoSection(BuildContext context) {
    final teamPrimary = colorFromHex(_primaryColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Team Logo'),
        Text(
          'Choose a logo that matches your team\'s name or identity.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 12),
        // "No logo" chip + selected preview
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _logoAsset = null);
                widget.onLogoChanged(null);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _logoAsset == null ? teamPrimary.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
                  border: Border.all(color: _logoAsset == null ? teamPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2), width: _logoAsset == null ? 2 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sports_hockey_rounded, size: 28, color: _logoAsset == null ? teamPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35)),
              ),
            ),
            if (_logoAsset != null) ...[
              const SizedBox(width: 10),
              Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: teamPrimary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/avatars/teams/$_logoAsset.png', fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kTeamLogos.firstWhere((l) => l.key == _logoAsset, orElse: () => TeamLogo(_logoAsset!, _logoAsset!, '')).name,
                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: Theme.of(context).colorScheme.onPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No logo selected',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Logo grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
          itemCount: kTeamLogos.length,
          itemBuilder: (_, i) {
            final logo = kTeamLogos[i];
            final isSelected = _logoAsset == logo.key;
            return GestureDetector(
              onTap: () {
                setState(() => _logoAsset = logo.key);
                widget.onLogoChanged(logo.key);
              },
              child: Tooltip(
                message: '${logo.name}\n${logo.mascot}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? teamPrimary.withValues(alpha: 0.1) : Colors.transparent,
                    border: Border.all(color: isSelected ? teamPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12), width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(logo.assetPath, fit: BoxFit.contain),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Color swatches ────────────────────────────────────────────────────────
  Widget _buildColorRow(BuildContext context, List<String> palette, String selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: palette.map((hex) {
        final color = colorFromHex(hex);
        final isSelected = selected.toUpperCase() == hex.toUpperCase();
        return GestureDetector(
          onTap: () => onTap(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2.5) : Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.18), width: 1),
              boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)] : null,
            ),
            child: isSelected ? Icon(Icons.check, size: 16, color: _contrastColor(color)) : null,
          ),
        );
      }).toList(),
    );
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.35 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final teamPrimary = colorFromHex(_primaryColor);
    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            _buildLogoSection(context),

            const SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08)),
            const SizedBox(height: 16),

            // Primary color
            _sectionLabel(context, 'Primary Color'),
            Text(
              'Used for the progress bar, buttons, and accents.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            _buildColorRow(context, kPrimaryColors, _primaryColor, (hex) {
              setState(() => _primaryColor = hex);
              widget.onPrimaryColorChanged(hex);
            }),

            const SizedBox(height: 16),

            // Dark accent
            _sectionLabel(context, 'Dark Accent'),
            Text(
              'A dark shade for contrast — jersey numbers, borders.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            _buildColorRow(context, kDarkAccentColors, _darkAccent, (hex) {
              setState(() => _darkAccent = hex);
              widget.onDarkAccentChanged(hex);
            }),

            const SizedBox(height: 16),

            // Light accent
            _sectionLabel(context, 'Light Accent'),
            Text(
              'A light shade for backgrounds and highlights.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            _buildColorRow(context, kLightAccentColors, _lightAccent, (hex) {
              setState(() => _lightAccent = hex);
              widget.onLightAccentChanged(hex);
            }),

            const SizedBox(height: 16),

            // Live preview strip
            _sectionLabel(context, 'Preview'),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(flex: 5, child: Container(color: colorFromHex(_darkAccent))),
                    Expanded(flex: 6, child: Container(color: teamPrimary)),
                    Expanded(flex: 5, child: Container(color: colorFromHex(_lightAccent))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared team logo / color display helpers ─────────────────────────────────

/// Builds a small round team logo widget. Shows the asset logo if [logoAsset]
/// is set, otherwise falls back to a hockey icon using [primaryColorHex].
Widget buildTeamLogoWidget({
  required BuildContext context,
  required String? logoAsset,
  required String? primaryColorHex,
  double size = 44,
  double iconSize = 22,
}) {
  final teamColor = colorFromHex(primaryColorHex);
  if (logoAsset != null) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.10), shape: BoxShape.circle),
      child: ClipOval(child: Padding(padding: EdgeInsets.all(size * 0.1), child: Image.asset('assets/images/avatars/teams/$logoAsset.png', fit: BoxFit.contain))),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.12), shape: BoxShape.circle),
    child: Icon(Icons.group_rounded, color: teamColor, size: iconSize),
  );
}
