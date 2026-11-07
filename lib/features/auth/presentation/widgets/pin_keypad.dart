import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';

class PinKeypad extends StatefulWidget {
  const PinKeypad({
    super.key,
    this.randomized = false,
    required this.onDigit,
    required this.onDelete,
  });
  final bool randomized;
  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
  @override
  void initState() {
    super.initState();
    if (widget.randomized) digits.shuffle();
  }

  Widget keyButton(int digit) => FilledButton(
    style: FilledButton.styleFrom(
      shape: const CircleBorder(),
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(54),
      backgroundColor: const Color(0xffe8f2ef),
      foregroundColor: AppColors.ink,
    ),
    onPressed: () => widget.onDigit(digit),
    child: Text(
      '$digit',
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
    ),
  );
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Center(
                        child: row < 3
                            ? keyButton(digits[row * 3 + col])
                            : switch (col) {
                                0 => IconButton(
                                  tooltip: 'Borrar último dígito',
                                  onPressed: widget.onDelete,
                                  icon: const Icon(Icons.backspace_outlined),
                                ),
                                1 => keyButton(digits.last),
                                _ => const SizedBox.shrink(),
                              },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
