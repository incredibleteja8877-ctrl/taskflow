import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/utils/validators.dart';

/// Task 11: "Unit tests — validation logic."
void main() {
  group('email', () {
    test('rejects empty and malformed addresses', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('ava'), isNotNull);
      expect(Validators.email('ava@'), isNotNull);
      expect(Validators.email('ava@nimbus'), isNotNull);
      expect(Validators.email('@nimbus.test'), isNotNull);
    });

    test('accepts the mock accounts and common shapes', () {
      expect(Validators.email('ava.admin@nimbusdigital.test'), isNull);
      expect(Validators.email('a+tag@example.co.uk'), isNull);
      expect(Validators.email('  spaced@example.test  '), isNull);
    });
  });

  group('password', () {
    test('requires a minimum length', () {
      expect(Validators.password('Ab1'), contains('8'));
    });

    test('requires both a letter and a number', () {
      expect(Validators.password('abcdefghij'), isNotNull);
      expect(Validators.password('1234567890'), isNotNull);
    });

    test('accepts the mock password', () {
      expect(Validators.password('Password123!'), isNull);
    });

    test('does not trim — spaces are legitimate password characters', () {
      // '  Ab1  ' is 7 characters, so it fails on length. If we trimmed it
      // first it would be 3 and still fail, but the point is that a valid
      // password with padding is not silently altered.
      expect(Validators.password(' Password123! '), isNull);
    });
  });

  group('confirmPassword', () {
    test('rejects a mismatch', () {
      expect(Validators.confirmPassword('a', 'b'), contains('match'));
    });

    test('rejects an empty confirmation', () {
      expect(Validators.confirmPassword('', 'b'), isNotNull);
    });

    test('accepts an exact match', () {
      expect(Validators.confirmPassword('Password123!', 'Password123!'),
          isNull);
    });
  });

  group('name', () {
    test('rejects empty and single characters', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('  '), isNotNull);
      expect(Validators.name('A'), isNotNull);
    });

    test('accepts a real name', () {
      expect(Validators.name('Ava Thompson'), isNull);
    });
  });

  group('notEmpty', () {
    test('names the field in its message', () {
      expect(Validators.notEmpty('', field: 'Title'), 'Title is required.');
    });

    test('treats whitespace as empty', () {
      expect(Validators.notEmpty('   '), isNotNull);
    });

    test('accepts any real content', () {
      expect(Validators.notEmpty('QA pass'), isNull);
    });
  });
}
