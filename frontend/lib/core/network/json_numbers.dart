// Reads the numeric fields the backend sends.
//
// Amounts are `Decimal` on the server and Pydantic serialises them as JSON
// strings to keep the precision. A client that only accepts a JSON number
// therefore fails on the first response that carries an amount.

/// Reads a number the backend may have sent as a number or as a string.
double? readDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

/// Reads an integer the backend may have sent as a number or as a string.
int? readInt(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
