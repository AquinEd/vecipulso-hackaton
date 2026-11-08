import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/map_origin.dart';

abstract interface class MapOriginRepository {
  Future<MapOrigin?> load();
}

class SupabaseMapOriginRepository implements MapOriginRepository {
  SupabaseMapOriginRepository(this.client);
  final SupabaseClient client;
  @override
  Future<MapOrigin?> load() async {
    final user = client.auth.currentUser?.id;
    if (user == null) return null;
    final zoneId = await client
        .rpc('mi_zona')
        .timeout(const Duration(seconds: 15));
    if (user != client.auth.currentUser?.id) throw const FormatException();
    if (zoneId == null) return null;
    final row = await client
        .from('zonas')
        .select('nombre,centro')
        .eq('id', zoneId as String)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    if (user != client.auth.currentUser?.id) throw const FormatException();
    if (row == null) return null;
    return MapOrigin(
      GeoCoordinate.fromGeography(row['centro']),
      'Centro de tu zona: ${row['nombre']} · no es tu posición GPS',
    );
  }
}
