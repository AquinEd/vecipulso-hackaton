import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';

class RegistrationStepIndicator extends StatelessWidget {
  const RegistrationStepIndicator({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso $step de 3',
    excludeSemantics: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 1; i <= 3; i++)
          CircleAvatar(
            radius: 15,
            backgroundColor: i <= step ? AppColors.primary : AppColors.border,
            foregroundColor: i <= step ? Colors.white : AppColors.secondaryText,
            child: i < step ? const Icon(Icons.check, size: 16) : Text('$i'),
          ),
      ],
    ),
  );
}
