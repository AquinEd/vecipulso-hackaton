import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';
import '../../../../shared/widgets/cards/app_card.dart';

typedef DemoNotice = ({
  String id,
  IconData icon,
  String title,
  String body,
  String date,
});
const demoNotices = <DemoNotice>[
  (
    id: 'comunidad',
    icon: Icons.groups_outlined,
    title: 'Taller comunitario',
    body: 'Vista previa de una invitación al taller.',
    date: '5 nov.',
  ),
  (
    id: 'servicios',
    icon: Icons.storefront,
    title: 'Directorio de servicios',
    body: 'Ejemplo de una ficha de servicio local.',
    date: '4 nov.',
  ),
  (
    id: 'publicaciones',
    icon: Icons.article_outlined,
    title: 'Publicación de ejemplo',
    body: 'Así se mostraría un aviso sobre una publicación.',
    date: '3 nov.',
  ),
  (
    id: 'solidaridad',
    icon: Icons.volunteer_activism,
    title: 'Intercambio solidario',
    body: 'Ejemplo de una convocatoria de intercambio.',
    date: '2 nov.',
  ),
  (
    id: 'seguridad',
    icon: Icons.health_and_safety_outlined,
    title: 'Guía de emergencias',
    body: 'Vista previa informativa del tablero SOS.',
    date: '1 nov.',
  ),
];

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.readIds,
    this.notices = demoNotices,
  });
  final Set<String> readIds;
  final List<DemoNotice> notices;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool unreadOnly = false;
  @override
  Widget build(BuildContext context) {
    final unread = widget.notices.where((n) => !widget.readIds.contains(n.id));
    final visible = unreadOnly ? unread : widget.notices;
    return GuidePage(
      title: 'Notificaciones',
      children: [
        const Text('Notificaciones de ejemplo'),
        if (context.watch<AccessibilityController?>()?.clearInstructions ??
            false)
          const Text(
            'Toca un aviso para marcarlo como leído. Puedes filtrar los que quedan pendientes.',
          ),
        Semantics(liveRegion: true, child: Text('No leídas: ${unread.length}')),
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in [
              (false, 'Todas'),
              (true, 'No leídas'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: unreadOnly == value,
                onSelected: (_) => setState(() => unreadOnly = value),
              ),
          ],
        ),
        OutlinedButton(
          onPressed: unread.isEmpty
              ? null
              : () => setState(
                  () => widget.readIds.addAll(widget.notices.map((n) => n.id)),
                ),
          child: const Text('Marcar todas como leídas'),
        ),
        if (visible.isEmpty)
          Text(
            widget.notices.isEmpty
                ? 'Sin notificaciones'
                : 'Sin notificaciones no leídas',
          ),
        for (final notice in visible)
          AppCard(
            child: ListTile(
              leading: Icon(notice.icon),
              title: Text(notice.title),
              subtitle: Text(
                '${notice.body}\nDemo · ${notice.date} · ${widget.readIds.contains(notice.id) ? "Leída" : "No leída"}',
              ),
              onTap: widget.readIds.contains(notice.id)
                  ? null
                  : () => setState(() => widget.readIds.add(notice.id)),
            ),
          ),
      ],
    );
  }
}
