import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/auth_failure.dart';
import '../models/auth_models.dart';

abstract interface class AuthRepository {
  String? get userId;
  Stream<String?> get sessions;
  Future<void> restore();
  Future<List<Zone>> zones();
  Future<Profile?> profile(String id);
  Future<String> ensureSession();
  Future<void> register(Registration draft, String pin);
  Future<PinResult> verify(String pin);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);
  final SupabaseClient client;
  static const timeout = Duration(seconds: 20);
  @override
  String? get userId => client.auth.currentSession?.user.id;
  @override
  Stream<String?> get sessions =>
      client.auth.onAuthStateChange.map((e) => e.session?.user.id).distinct();
  @override
  Future<void> restore() async {
    if (client.auth.currentSession?.isExpired == true) {
      await client.auth.refreshSession().timeout(timeout);
    }
  }

  @override
  Future<List<Zone>> zones() async {
    final rows = await client
        .from('zonas')
        .select('id,nombre')
        .order('nombre')
        .timeout(timeout);
    return [
      for (final row in rows)
        (id: row['id'] as String, name: row['nombre'] as String),
    ];
  }

  @override
  Future<Profile?> profile(String id) async {
    final row = await client
        .from('perfiles')
        .select('id')
        .eq('id', id)
        .maybeSingle()
        .timeout(timeout);
    return row == null ? null : (userId: row['id'] as String);
  }

  Future<AuthResponse>? _pendingSignIn;

  @override
  Future<String> ensureSession() async {
    if (userId == null) {
      final pending = _pendingSignIn ??= client.auth
          .signInAnonymously()
          .whenComplete(() {
            _pendingSignIn = null;
          });
      await pending.timeout(timeout);
    }
    return userId ?? (throw AuthFailure.session);
  }

  @override
  Future<void> register(Registration draft, String pin) async {
    await client
        .rpc(
          'registrar_completo',
          params: {
            'p_dni': draft.dni,
            'p_nombre_completo': draft.name,
            'p_zona': draft.zone,
            'p_consentimiento': draft.consent,
            'p_pin': pin,
          },
        )
        .timeout(timeout);
  }

  @override
  Future<PinResult> verify(String pin) async => PinResult.parse(
    await client.rpc('verificar_pin', params: {'p_pin': pin}).timeout(timeout),
  );
}
