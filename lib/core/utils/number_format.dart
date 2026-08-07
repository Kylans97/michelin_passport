/// Formats a non-negative integer with thousands separators, e.g.
/// `formatThousands(1461) == '1,461'`. Used for Explore's result counts.
String formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
