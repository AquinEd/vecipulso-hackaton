import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_emergency_actions.dart';
import '../../models/emergency_action_option.dart';
import '../../models/emergency_action_type.dart';
import '../widgets/emergency_action_card.dart';
import '../widgets/emergency_action_selector.dart';

class EmergencyActionsScreen extends StatefulWidget {
  const EmergencyActionsScreen({super.key, this.initialAction});
  final EmergencyActionType? initialAction;
  @override
  State<EmergencyActionsScreen> createState() => _EmergencyActionsScreenState();
}

class _EmergencyActionsScreenState extends State<EmergencyActionsScreen> {
  bool modalOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialAction == null) return;
      openAction(
        demoEmergencyActions.firstWhere((a) => a.type == widget.initialAction),
      );
    });
  }

  Future<void> openAction(EmergencyActionDefinition action) async {
    if (modalOpen) return;
    modalOpen = true;
    try {
      final category = await showModalBottomSheet<EmergencyActionCategory>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => EmergencyActionSelector(action: action),
      );
      if (mounted && category != null) {
        context.go(AppRoute.help.path, extra: category);
      }
    } finally {
      modalOpen = false;
    }
  }

  void back() => context.go(AppRoute.sos.path);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
        leading: BackButton(onPressed: back),
        title: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => AppNavigation.exitSos(context),
            child: const Text('Salir del Modo SOS'),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.error,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'VeciPulso SOS',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Centro de ayuda vecinal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        emergencyDemoNotice,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionHeader(title: '¿Qué necesitas hacer?'),
                        const SizedBox(height: 20),
                        for (final action in demoEmergencyActions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: EmergencyActionCard(
                              key: ValueKey(action.type),
                              action: action,
                              onSelect: () => openAction(action),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff2da),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.warningText,
                              ),
                              SizedBox(width: 12),
                              Expanded(child: Text(emergencyDemoLocation)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
