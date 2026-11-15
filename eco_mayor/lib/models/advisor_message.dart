class AdvisorMessage {
  final String advisorId;
  final String advisorName;
  final String title;
  final String portraitAsset;
  final String message;
  final String evsConcept; // Educational takeaway

  const AdvisorMessage({
    required this.advisorId,
    required this.advisorName,
    required this.title,
    required this.portraitAsset,
    required this.message,
    required this.evsConcept,
  });
}
