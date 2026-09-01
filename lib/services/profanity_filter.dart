class ProfanityFilter {
  static const List<String> _words = [
    'fuck',
    'shit',
    'ass',
    'bitch',
    'cunt',
    'dick',
    'cock',
    'pussy',
    'whore',
    'slut',
    'bastard',
    'crap',
    'piss',
    'fag',
    'faggot',
    'nigger',
    'nigga',
    'kike',
    'chink',
    'spic',
    'wetback',
    'retard',
    'motherfucker',
    'asshole',
    'bullshit',
    'jackass',
    'dumbass',
    'dipshit',
    'shithead',
    'fuckhead',
    'twat',
    'wanker',
    'arsehole',
  ];

  /// Returns true if [text] contains any profane word (case-insensitive, whole-word match).
  static bool containsProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _words) {
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
  }
}
