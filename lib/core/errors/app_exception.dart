/// Typed failures surfaced to the UI (SRS FR-SEARCH-06, FR-PLAY-06, NFR-REL).
abstract class AppException implements Exception {
  const AppException(this.userMessage);

  /// Text that is safe to show to the user.
  final String userMessage;

  @override
  String toString() => '$runtimeType: $userMessage';
}

class NetworkException extends AppException {
  const NetworkException([super.userMessage = 'No connection. Check your internet and try again.']);
}

class RateLimitException extends AppException {
  const RateLimitException([super.userMessage = 'Too many requests. Please wait a moment and retry.']);
}

class MalformedResponseException extends AppException {
  const MalformedResponseException([super.userMessage = 'The provider returned data CLICK could not read.']);
}

/// A track (or stream) the provider no longer offers (FR-LIB-07, FR-PLAY-06).
class ProviderUnavailableException extends AppException {
  const ProviderUnavailableException([super.userMessage = 'This track is no longer available from the provider.']);
}

/// The provider rejected CLICK's credentials (missing/invalid/restricted API key).
class ProviderConfigException extends AppException {
  const ProviderConfigException(
      [super.userMessage = 'The music provider rejected CLICK\'s API key. Check the key and its restrictions.']);
}

class ValidationException extends AppException {
  const ValidationException(super.userMessage);
}
