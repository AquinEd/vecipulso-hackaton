import '../../solidarity/models/solidarity_post.dart';
import '../data/publication_templates.dart';

class PublicationDraft {
  PublicationDraft(this.type, this.title, this.description);
  final PostType type;
  String title, description;
  static const neighborhood = 'Barrio Los Álamos · Ubicación de ejemplo';
  static const titleLimit = 80, detailLimit = 500;
  String get category => publicationTemplates[type]!.label;
}

class PublicationDraftController {
  PublicationDraft? draft, preview;

  void select(PostType type) {
    final template = publicationTemplates[type];
    if (template == null || draft?.type == type) return;
    draft = PublicationDraft(type, template.title, template.detail);
  }

  bool confirm() {
    final current = draft;
    if (current == null || current.title.trim().isEmpty) return false;
    preview = PublicationDraft(
      current.type,
      current.title.trim(),
      current.description.trim(),
    );
    draft = null;
    return true;
  }

  void clear() {
    draft = null;
    preview = null;
  }
}
