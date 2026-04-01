import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/tabs/Friends.dart';
import 'package:tenthousandshotchallenge/tabs/Team.dart';

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
    final selected = selectedSection == CommunitySection.team ? CommunitySection.team.name : CommunitySection.friends.name;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: selected,
            children: const {
              'friends': Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Text('Friends'),
              ),
              'team': Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Text('Team'),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              onSectionChanged(
                value == CommunitySection.team.name ? CommunitySection.team : CommunitySection.friends,
              );
            },
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
