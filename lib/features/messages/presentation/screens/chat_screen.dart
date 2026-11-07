import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';
import '../../data/demo_conversations.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final item = demoConversations.where((c) => c.id == id).firstOrNull;
    final colors = Theme.of(context).colorScheme;
    return GuidePage(
      title: item == null
          ? 'Conversación no encontrada'
          : 'Chat de demostración',
      fallback: AppRoute.messages,
      children: [
        if (item == null)
          TextButton(
            onPressed: () => GuidePage.close(context, AppRoute.messages),
            child: const Text('Volver a Mensajes'),
          )
        else ...[
          ListTile(
            leading: CircleAvatar(child: Text(item.firstName[0])),
            title: Text(item.publicName),
            subtitle: Text(item.topic),
          ),
          for (final (author, body, mine) in [
            ('Tú (demo)', item.question, true),
            (item.publicName, item.reply, false),
          ])
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: .85,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: mine
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('$author\n$body'),
                  ),
                ),
              ),
            ),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Mensaje',
              suffixIcon: IconButton(
                onPressed: null,
                icon: Icon(Icons.send),
                tooltip: 'Envío deshabilitado',
              ),
            ),
          ),
          const Text('Envío disponible al integrar mensajería'),
        ],
      ],
    );
  }
}
