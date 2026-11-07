import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.sos = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool sos;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: sos
        ? FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          )
        : null,
    icon: Icon(icon),
    label: Text(label),
  );
}
