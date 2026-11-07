import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_solidarity_posts.dart';
import '../../models/solidarity_post.dart';
import '../widgets/solidarity_post_card.dart';

class SolidarityWallScreen extends StatefulWidget {
  const SolidarityWallScreen({
    super.key,
    this.mode = WallMode.wall,
    this.posts = demoSolidarityPosts,
  });
  final WallMode mode;
  final List<SolidarityPost> posts;
  @override
  State<SolidarityWallScreen> createState() => _SolidarityWallScreenState();
}

class _SolidarityWallScreenState extends State<SolidarityWallScreen> {
  PostType? filter;
  @override
  Widget build(BuildContext context) {
    final economy = widget.mode == WallMode.economy;
    final posts = visiblePosts(widget.posts, widget.mode, filter);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 1 + posts.length + (posts.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BackButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(
                          economy
                              ? AppRoute.solidarity.path
                              : AppRoute.home.path,
                        );
                      }
                    },
                  ),
                  Expanded(
                    child: AppSectionHeader(
                      title: economy
                          ? 'Economía solidaria'
                          : 'Muro Colaborativo',
                    ),
                  ),
                ],
              ),
              if (economy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Todo sin dinero: juntos nos apoyamos'),
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final type in const [
                        null,
                        PostType.offer,
                        PostType.need,
                        PostType.donation,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            showCheckmark: false,
                            shape: const StadiumBorder(),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: filter == type
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                            label: Text(type?.label ?? 'Todos'),
                            selected: filter == type,
                            onSelected: (_) => setState(() => filter = type),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: const Text('Explorar economía solidaria'),
                  onPressed: () => context.push(AppRoute.expanded.path),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Datos de demostración · Recomendaciones ilustrativas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        }
        if (posts.isEmpty) {
          return Column(
            children: [
              const Text('No hay publicaciones de esta categoría'),
              if (filter != null)
                AppButton(
                  label: 'Volver a Todos',
                  icon: Icons.list,
                  onPressed: () => setState(() => filter = null),
                ),
            ],
          );
        }
        final post = posts[index - 1];
        return Padding(
          key: ValueKey(post.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: SolidarityPostCard(post: post, mode: widget.mode),
        );
      },
    );
  }
}
