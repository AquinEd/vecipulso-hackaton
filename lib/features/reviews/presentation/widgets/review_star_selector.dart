import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReviewStarSelector extends StatelessWidget {
  const ReviewStarSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        children: [
          for (var star = 1; star <= 5; star++)
            Semantics(
              selected: star == value,
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: star == 1 ? '1 estrella' : '$star estrellas',
                onPressed: () => onChanged(star),
                icon: Icon(
                  star <= value ? Icons.star : Icons.star_border,
                  color: star <= value ? AppColors.stars : Colors.grey.shade700,
                  size: 32,
                ),
              ),
            ),
        ],
      ),
      Semantics(
        liveRegion: true,
        child: Text(value == 0 ? 'Sin calificación' : '$value de 5 estrellas'),
      ),
    ],
  );
}
