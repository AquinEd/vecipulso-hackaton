import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../common/app_asset_image.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({
    super.key,
    required this.title,
    required this.children,
    this.fallback = AppRoute.home,
  });
  final AppRoute fallback;
  final String title;
  final List<Widget> children;

  static void close(BuildContext context, [AppRoute fallback = AppRoute.home]) {
    if (context.canPop()) {
      context.pop();
    } else {
      // The router redirects Inicio to the dashboard when SOS is active.
      context.go(fallback.path);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close(context, fallback);
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const AppAssetImage(
          path: AppAssets.vecipulsoLogoHorizontalPNG,
          label: 'VeciPulso',
          height: 44,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  BackButton(onPressed: () => close(context, fallback)),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}
