import 'package:flutter/material.dart';

import '../../models/community_map_marker.dart';

class NeighborhoodMapCanvas extends StatelessWidget {
  const NeighborhoodMapCanvas({
    super.key,
    required this.markers,
    required this.onSelect,
  });
  final List<CommunityMapMarker> markers;
  final ValueChanged<CommunityMapMarker> onSelect;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 740 / 920,
      child: LayoutBuilder(
        builder: (context, size) => Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _Streets()),
            for (final marker in markers)
              Positioned(
                left: (size.maxWidth * marker.relativeX - 24).clamp(
                  0,
                  size.maxWidth - 48,
                ),
                top: (size.maxHeight * marker.relativeY - 24).clamp(
                  0,
                  size.maxHeight - 48,
                ),
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: '${marker.title} · ${marker.category.label}',
                  padding: EdgeInsets.zero,
                  icon: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: marker.category.color,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        marker.category.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  onPressed: () => onSelect(marker),
                ),
              ),
            if (markers.isEmpty)
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: const Text(
                        'No hay coincidencias. Cambia la búsqueda o los filtros.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Streets extends CustomPainter {
  const _Streets();
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
  bool shouldRepaint(_Streets oldDelegate) => false;
}
