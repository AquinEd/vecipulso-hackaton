import 'package:flutter/widgets.dart' show StringCharacters;

String formatProviderDisplayName(String firstName, String paternalSurname) {
  final first = firstName.trim().split(RegExp(r'\s+')).first;
  final surname = paternalSurname.trim().characters;
  final length = switch (surname.length) {
    > 4 => 4,
    4 => 2,
    _ => 1,
  };
  return [
    first,
    surname.take(length).toString(),
  ].where((part) => part.isNotEmpty).join(' ');
}
