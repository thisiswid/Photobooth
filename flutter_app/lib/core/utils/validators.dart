/// Form validation utilities for SnapTechBooth.
///
/// No email validator — email is not part of this system (business rule #15).
abstract final class Validators {
  /// Validates that a required field is not empty.
  static String? required(String? value, [String fieldName = 'Field ini']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  /// Validates a phone number (Indonesian format).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final phoneRegex = RegExp(r'^(\+62|62|0)[0-9]{9,13}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Nomor telepon tidak valid';
    }
    return null;
  }

  /// Validates minimum length.
  static String? Function(String?) minLength(int min, [String? fieldName]) {
    return (String? value) {
      if (value == null || value.length < min) {
        return '${fieldName ?? "Field"} minimal $min karakter';
      }
      return null;
    };
  }

  /// Combines multiple validators — returns the first error found.
  static String? Function(String?) combine(
      List<String? Function(String?)> validators) {
    return (String? value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
