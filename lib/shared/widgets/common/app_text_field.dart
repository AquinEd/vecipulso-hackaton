import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.formatters,
    this.maxLines = 1,
    this.maxLength,
    this.next = false,
    this.onSubmitted,
    this.suffixIcon,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final int maxLines;
  final int? maxLength;
  final bool next;
  final VoidCallback? onSubmitted;
  final Widget? suffixIcon;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    validator: validator,
    keyboardType: keyboardType,
    inputFormatters: formatters,
    textCapitalization: keyboardType == TextInputType.name
        ? TextCapitalization.words
        : TextCapitalization.none,
    textInputAction: maxLines > 1
        ? TextInputAction.newline
        : next
        ? TextInputAction.next
        : TextInputAction.done,
    onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    decoration: InputDecoration(
      suffixIcon: suffixIcon,
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(icon),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
