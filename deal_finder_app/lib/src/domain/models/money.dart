/// Philippine pesos stored as integer centavos. Serialization is lossless.
final class Money implements Comparable<Money> {
  const Money(this.centavos);
  final int centavos;

  factory Money.parse(Object value) {
    final text = value
        .toString()
        .replaceAll(RegExp(r'PHP|₱|,', caseSensitive: false), '')
        .trim();
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(text)) {
      throw const FormatException(
        'Enter a peso amount with at most two decimal places.',
      );
    }
    final parts = text.replaceFirst('-', '').split('.');
    final cents =
        int.parse(parts.first) * 100 +
        int.parse(parts.length == 1 ? '0' : parts.last.padRight(2, '0'));
    return Money(text.startsWith('-') ? -cents : cents);
  }

  static Money? optional(Object? value) =>
      value == null || value.toString().trim().isEmpty
      ? null
      : Money.parse(value);
  String get decimal =>
      '${centavos < 0 ? '-' : ''}${centavos.abs() ~/ 100}.${(centavos.abs() % 100).toString().padLeft(2, '0')}';
  String get formatted {
    final digits = (centavos.abs() ~/ 100).toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${centavos < 0 ? '-' : ''}₱$grouped${centavos % 100 == 0 ? '' : '.${(centavos.abs() % 100).toString().padLeft(2, '0')}'}';
  }

  Money operator -(Money other) => Money(centavos - other.centavos);
  @override
  int compareTo(Money other) => centavos.compareTo(other.centavos);
  @override
  bool operator ==(Object other) =>
      other is Money && other.centavos == centavos;
  @override
  int get hashCode => centavos.hashCode;
  @override
  String toString() => decimal;
}
