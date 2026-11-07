import 'package:flutter/material.dart';

class IllustratedStreetsPainter extends CustomPainter {
  const IllustratedStreetsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 740, size.height / 920);
    canvas.drawColor(const Color(0xffe8f2ed), BlendMode.src);
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 11;
    for (double x = -370; x < 740; x += 74) {
      canvas.drawLine(Offset(x, 0), Offset(x + 338, 920), street);
    }
    for (double y = 0; y < 1100; y += 83) {
      canvas.drawLine(Offset(0, y), Offset(740, y - 136), street);
    }
    final park = Paint()..color = const Color(0xffcfe6cf);
    for (final center in const [
      Offset(138, 138),
      Offset(538, 80),
      Offset(359, 218),
      Offset(374, 567),
      Offset(102, 642),
      Offset(625, 689),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 90, height: 66),
        park,
      );
    }
  }

  @override
  bool shouldRepaint(IllustratedStreetsPainter oldDelegate) => false;
}
