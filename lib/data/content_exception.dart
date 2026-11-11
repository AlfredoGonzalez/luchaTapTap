/// Thrown when a content file (JSON) is missing, malformed or inconsistent.
/// Always names the file and path so the designer can fix the data fast.
class ContentException implements Exception {
  ContentException(this.message);

  final String message;

  @override
  String toString() => 'ContentException: $message';
}
