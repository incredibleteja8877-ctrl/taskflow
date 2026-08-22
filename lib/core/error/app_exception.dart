/// Every error our data and domain layers can raise.
///
/// This is `sealed`, which means the compiler knows the complete list of
/// subtypes. When the UI switches over an AppException, Dart will refuse to
/// compile if we forget a case — so adding a new error type later can never
/// silently produce an unhandled blank screen.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Safe to show directly to the user.
  /// Never put a token, a stack trace, or raw JSON in here.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Simulated 404 — the record does not exist.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'We could not find what you were looking for.']);
}

/// Simulated network timeout.
/// Named "Network..." on purpose: `dart:async` already exports a
/// `TimeoutException`, and a name collision here would be painful later.
class NetworkTimeoutException extends AppException {
  const NetworkTimeoutException([super.message = 'The request timed out. Please try again.']);
}

/// Simulated 422 — the input was rejected.
/// [fieldErrors] maps a form field name to its error, so a screen can show
/// the message inline on the offending TextFormField instead of in a snackbar.
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;
}

/// Simulated 401 — no valid session. Triggers the logout redirect.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Your session has expired. Please sign in again.']);
}

/// Simulated 403 — signed in, but not allowed.
/// This is what a member gets when they try to delete a project.
class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'You do not have permission to do that.']);
}

/// The simulated connectivity toggle is switched off.
class OfflineException extends AppException {
  const OfflineException([super.message = 'You are offline. Showing your last saved data.']);
}

/// Anything we did not anticipate. The catch-all at the bottom of a try block.
class UnknownException extends AppException {
  const UnknownException([super.message = 'Something went wrong. Please try again.']);
}
