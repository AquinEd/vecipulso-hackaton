import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/demo_conversations.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String query = '';
  String? selected;
  @override
  Widget build(BuildContext context) {
    final matches = demoConversations.where((item) => item.matches(query));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Mensajes',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const Text('Conversaciones de demostración'),
        if (context.watch<AccessibilityController?>()?.clearInstructions ??
            false)
          const Text(
            'Busca por nombre o tema y toca una conversación para leerla.',
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar conversaciones',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
        ),
        if (matches.isEmpty) const Text('Sin resultados de búsqueda'),
        for (final item in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: ListTile(
                selected: selected == item.id,
                leading: CircleAvatar(child: Text(item.firstName[0])),
                title: Text(item.publicName),
                subtitle: Text(
                  '${item.topic}\n${item.reply}\nDemo · ${item.time}',
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => selected = item.id);
                  context.push(AppRoute.chat.path.replaceFirst(':id', item.id));
                },
              ),
            ),
          ),
      ],
    );
  }
}
