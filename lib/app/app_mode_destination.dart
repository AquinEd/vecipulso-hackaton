import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/emergency/presentation/screens/emergency_dashboard_screen.dart';
import '../features/emergency/presentation/screens/emergency_map_placeholder_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/maps/presentation/screens/neighborhood_map_screen.dart';
import 'app_mode_controller.dart';

/// Stable pages retain the normal map filters when entering and leaving SOS.
class AppModeDestination extends StatelessWidget {
  const AppModeDestination({super.key, this.map = false});
  final bool map;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: context.watch<AppModeController>().isSos ? 1 : 0,
    children: map
        ? const [NeighborhoodMapScreen(), EmergencyMapPlaceholderScreen()]
        : const [HomeScreen(), EmergencyDashboardScreen()],
  );
}
