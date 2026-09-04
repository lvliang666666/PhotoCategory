import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/media_thumbnail.dart';
import '../library/library_controller.dart';
import '../photo_viewer/photo_viewer_page.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryController()..initialize(),
      child: Consumer<LibraryController>(builder: (context, controller, _) {
        if (controller.isLoading)
          return const Center(child: CircularProgressIndicator());
        if (controller.photos.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_month_outlined,
            title: '暂无时间线',
            subtitle: '手动导入照片后，会按年、月显示在这里。',
          );
        }
        final groups = <String, List<int>>{};
        for (var i = 0; i < controller.photos.length; i++) {
          final seconds =
              controller.photos[i].takenAt ?? controller.photos[i].importedAt;
          final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          final key = '${date.year} 年 ${date.month} 月';
          groups.putIfAbsent(key, () => []).add(i);
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 600) controller.loadMore();
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 112,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  title: Text('时间线',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              for (final entry in groups.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Text(entry.key,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, itemIndex) {
                      final index = entry.value[itemIndex];
                      final photo = controller.photos[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () async {
                            await controller.recordView(photo);
                            if (!context.mounted) return;
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PhotoViewerPage(
                                photos: controller.photos,
                                initialIndex: index,
                                themeName: entry.key,
                              ),
                            ));
                          },
                          child: MediaThumbnail(photo: photo),
                        ),
                      );
                    },
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: controller.hasMore
                        ? const CircularProgressIndicator()
                        : Text(
                            '已加载 ${controller.photos.length} / ${controller.totalCount} 张'),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
