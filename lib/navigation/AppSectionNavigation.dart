import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum AppSection {
  train,
  community,
  learn,
  me,
}

enum CommunitySection {
  friends,
  team,
}

String appSectionLocation(
  AppSection section, {
  CommunitySection? communitySection,
}) {
  switch (section) {
    case AppSection.train:
      return '/app?tab=train';
    case AppSection.community:
      final sectionValue = (communitySection ?? CommunitySection.friends).name;
      return '/app?tab=community&section=$sectionValue';
    case AppSection.learn:
      return '/app?tab=learn';
    case AppSection.me:
      return '/app?tab=me';
  }
}

void goToAppSection(
  BuildContext context,
  AppSection section, {
  CommunitySection? communitySection,
}) {
  context.go(
    appSectionLocation(
      section,
      communitySection: communitySection,
    ),
  );
}

void pushToAppSection(
  BuildContext context,
  AppSection section, {
  CommunitySection? communitySection,
}) {
  context.push(
    appSectionLocation(
      section,
      communitySection: communitySection,
    ),
  );
}
