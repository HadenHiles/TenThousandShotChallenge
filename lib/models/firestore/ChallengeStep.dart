class ChallengeStep {
  final int stepNumber;
  final String title;

  /// 'video', 'image', or 'gif'
  final String mediaType;
  final String mediaUrl;
  final String summary;

  ChallengeStep({
    required this.stepNumber,
    required this.title,
    required this.mediaType,
    required this.mediaUrl,
    required this.summary,
  });

  ChallengeStep.fromMap(Map<String, dynamic> map)
      : stepNumber = map['step_number'] ?? 0,
        title = map['title'] ?? '',
        mediaType = map['media_type'] ?? 'image',
        mediaUrl = map['media_url'] ?? '',
        summary = map['summary'] ?? '';

  Map<String, dynamic> toMap() {
    return {
      'step_number': stepNumber,
      'title': title,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'summary': summary,
    };
  }
}
