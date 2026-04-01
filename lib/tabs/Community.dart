import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/tabs/Friends.dart';
import 'package:tenthousandshotchallenge/tabs/Team.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

class _CommunityTabConfig {
  const _CommunityTabConfig({
    required this.section,
    required this.label,
    required this.icon,
  });

  final CommunitySection section;
  final String label;
  final IconData icon;
}

class Community extends StatelessWidget {
  const Community({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final CommunitySection selectedSection;
  final ValueChanged<CommunitySection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final darkHeaderColor = HomeTheme.darkTheme.colorScheme.primaryContainer;
    final dividerColor = Colors.white.withValues(alpha: 0.08);
    const tabs = [
      _CommunityTabConfig(
        section: CommunitySection.friends,
        label: 'Friends',
        icon: Icons.people_rounded,
      ),
      _CommunityTabConfig(
        section: CommunitySection.team,
        label: 'Team',
        icon: Icons.groups_rounded,
      ),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: darkHeaderColor,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Row(
            children: tabs.map((tab) {
              final isSelected = selectedSection == tab.section;
              return Expanded(
                child: InkWell(
                  onTap: () => onSectionChanged(tab.section),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Theme.of(context).primaryColor : dividerColor,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 22,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tab.label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: selectedSection == CommunitySection.team ? 1 : 0,
            children: const [
              Friends(),
              TeamPage(),
            ],
          ),
        ),
      ],
    );
  }
}
