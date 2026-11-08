typedef Zone = ({String id, String name});
typedef Registration = ({String dni, String name, String zone, bool consent});
typedef Profile = ({String userId});

class PinResult {
  const PinResult(this.ok, {this.reason, this.remaining, this.until});
  final bool ok;
  final String? reason;
  final int? remaining;
  final DateTime? until;
  factory PinResult.parse(dynamic row) {
    if (row is! Map || row['ok'] is! bool) throw const FormatException();
    final until = row['bloqueado_hasta'];
    return PinResult(
      row['ok'] as bool,
      reason: row['motivo'] as String?,
      remaining: row['intentos_restantes'] as int?,
      until: until == null ? null : DateTime.parse(until as String),
    );
  }
}
