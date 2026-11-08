import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/errors/auth_failure.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final problem = SupabaseConfig.problem;
  late final AuthController auth;
  if (problem != null) {
    auth = AuthController.unavailable(problem);
  } else {
    try {
      final supabase = await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.key,
        debug: false,
      );
      auth = AuthController(SupabaseAuthRepository(supabase.client));
    } catch (error) {
      auth = AuthController.unavailable(
        '${AuthFailure.from(error).message} Reinicia la aplicación.',
        configured: true,
      );
    }
  }
  runApp(VeciPulsoApp(auth: auth));
  if (auth.repository != null) unawaited(auth.restore());
}
