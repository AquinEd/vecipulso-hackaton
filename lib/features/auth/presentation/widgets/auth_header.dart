import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/core/constants/app_assets.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_asset_image.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.footer,
    this.dark = false,
  });
  final String title, subtitle;
  final Widget? footer;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: dark ? const Color(0xff0b3033) : null,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      children: [
        AppAssetImage(
          path: dark
              ? AppAssets.vecipulsoLogoParaFondoOscuroPNG
              : AppAssets.vecipulsoLogoHorizontalPNG,
          label: 'VeciPulso',
          height: 52,
          width: 180,
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: dark ? Colors.white : null),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: dark ? Colors.white : null),
        ),
        if (footer != null) ...[const SizedBox(height: 24), footer!],
      ],
    ),
  );
}

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
