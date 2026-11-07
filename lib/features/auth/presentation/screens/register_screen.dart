import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:hackaton_veci_pulso/shared/widgets/buttons/app_button.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_text_field.dart';

import '../../utils/auth_validators.dart';
import '../widgets/auth_header.dart';
import '../widgets/registration_step_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final dni = TextEditingController(), name = TextEditingController();
  void next() {
    if (!form.currentState!.validate()) return;
    name.text = AuthValidators.normalizeName(name.text);
    FocusScope.of(context).unfocus();
    context.push(AppRoute.pin.path);
  }

  @override
  void dispose() {
    dni.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    children: [
      const AuthHeader(
        title: 'Crea tu cuenta',
        subtitle: 'Registro rápido y seguro',
        footer: RegistrationStepIndicator(step: 1),
      ),
      const SizedBox(height: 18),
      Text(
        '1. Datos personales',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 14),
      Form(
        key: form,
        child: Column(
          children: [
            AppTextField(
              controller: dni,
              label: 'DNI (8 dígitos)',
              hint: '71234567',
              icon: Icons.badge_outlined,
              validator: AuthValidators.dni,
              keyboardType: TextInputType.number,
              next: true,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: name,
              label: 'Nombre completo',
              hint: 'María Torres Jara',
              icon: Icons.people_outline,
              validator: AuthValidators.name,
              keyboardType: TextInputType.name,
              onSubmitted: next,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Card(
        color: Color(0xffedf7f3),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shield_outlined),
            title: Text('Privacidad de tus datos'),
            subtitle: Text(
              'El DNI es autodeclarado. Todavía no hay verificación oficial de identidad. Tus datos solo se usan durante esta demostración.',
            ),
          ),
        ),
      ),
      const SizedBox(height: 36),
      AppButton(label: 'Continuar', icon: Icons.arrow_forward, onPressed: next),
    ],
  );
}
