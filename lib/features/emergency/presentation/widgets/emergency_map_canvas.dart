import 'package:flutter/material.dart';

import '../../../../shared/widgets/common/illustrated_streets_painter.dart';
import '../../models/emergency_map_marker.dart';

class EmergencyMapCanvas extends StatelessWidget {
  const EmergencyMapCanvas({
    super.key,
    required this.markers,
    required this.onSelect,
  });
  final List<EmergencyMapMarker> markers;
  final ValueChanged<EmergencyMapMarker> onSelect;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: .85,
      child: LayoutBuilder(
        builder: (context, size) => Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: IllustratedStreetsPainter()),
            const Align(
              alignment: Alignment(.12, -.12),
              child: FractionallySizedBox(
                widthFactor: .34,
                heightFactor: .38,
                child: ClipOval(
                  key: ValueKey('risk-oval'),
                  child: ColoredBox(color: Color(0x99f5ae9b)),
                ),
              ),
            ),
            for (final marker in markers)
              Positioned(
                left: (size.maxWidth - 48) * marker.position.dx,
                top: (size.maxHeight - 48) * marker.position.dy,
                width: 48,
                height: 48,
                child: IconButton(
                  key: ValueKey(marker.id),
                  tooltip: '${marker.title} · ${marker.category.label}',
                  padding: const EdgeInsets.all(3),
                  onPressed: () => onSelect(marker),
                  icon: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: marker.category.color,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      marker.category.icon,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
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
                        'Selecciona una categoría o Todos para ver marcadores.',
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
