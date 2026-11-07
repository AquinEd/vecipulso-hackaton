import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({super.key, required this.count, this.dark = false});
  final int count;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.primary;
    return Semantics(
      label: '$count de 6 dígitos ingresados',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++)
            Container(
              width: 15,
              height: 15,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                color: i < count ? color : Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}
