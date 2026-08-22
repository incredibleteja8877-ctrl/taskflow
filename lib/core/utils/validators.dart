/// Pure input validators shared by the forms and by the "server".
///
/// Each returns `null` when the value is acceptable and a message otherwise —
/// exactly the contract `TextFormField.validator` expects. So the same
/// function drives the UI and the repository, and the two can never disagree
/// about what "valid" means.
///
/// No Flutter import, no async, no state: trivially unit testable.
abstract final class Validators {
  static const int minPasswordLength = 8;
  static const int minNameLength = 2;

  /// Deliberately permissive. Strict RFC-5322 email regexes reject addresses
  /// that genuinely work; the only real test is sending mail. This catches
  /// typos, which is all a client-side check should attempt.
  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String? email(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Email is required.';
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (!_hasLetter.hasMatch(text) || !_hasDigit.hasMatch(text)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  /// Note the password is NOT trimmed anywhere in this file. Leading and
  /// trailing spaces are legitimate password characters, and silently
  /// stripping them would lock people out of their own accounts.
  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? name(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Name is required.';
    if (trimmed.length < minNameLength) {
      return 'That name looks too short.';
    }
    return null;
  }

  /// Generic non-empty check. [field] is interpolated into the message so the
  /// caller gets "Title is required." rather than "This field is required."
  static String? notEmpty(String? value, {String field = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$field is required.';
    return null;
  }
}
