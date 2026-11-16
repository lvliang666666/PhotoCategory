import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/feedback/interaction_feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/private_album_controller.dart';
import '../../widgets/clay_card.dart';
import '../app_lock/app_lock_pages.dart';
import 'ai_settings_page.dart';
import 'library_backup_page.dart';
import 'tag_management_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text('按你喜欢的方式保存与整理。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
          ),
          // Appearance section
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
            child: Text(
              '外观',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ClayCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题颜色',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<AppThemeController>(
                    builder: (context, controller, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          AppTheme.colorOptions.length,
                          (index) {
                            final option = AppTheme.colorOptions[index];
                            final isSelected = controller.colorIndex == index;

                            return GestureDetector(
                              onTap: () => controller.setColorIndex(index),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? option.seed.withOpacity(0.12)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? option.seed
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        width: isSelected ? 24 : 20,
                                        height: isSelected ? 24 : 20,
                                        decoration: BoxDecoration(
                                          color: option.seed,
                                          shape: BoxShape.circle,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: option.seed
                                                        .withOpacity(0.35),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    option.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: isSelected
                                              ? option.seed
                                              : colorScheme.onSurface
                                                  .withOpacity(0.5),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              '声音与触感',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Consumer<InteractionFeedbackController>(
            builder: (context, feedback, _) => ClayCard(
              child: SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('轻触反馈'),
                subtitle: const Text('按钮保留系统点击音，并增加苹果风格的轻微触感'),
                value: feedback.enabled,
                onChanged: feedback.setEnabled,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              '隐私与安全',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Consumer<AppLockController>(
            builder: (context, lock, _) => ClayCard(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline_rounded),
                    title: const Text('六位密码应用锁'),
                    subtitle: Text(lock.enabled
                        ? '已开启；冷启动或离开应用 30 秒后需要验证'
                        : '开启后输入六位数字密码才能进入应用'),
                    value: lock.enabled,
                    onChanged: (value) => _toggleAppLock(context, lock, value),
                  ),
                  if (lock.enabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: const Text('修改六位密码'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changeAppLockPin(context, lock),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Consumer2<PrivateAlbumController, AppLockController>(
            builder: (context, privacy, lock, _) => ClayCard(
              child: SwitchListTile(
                secondary: const Icon(Icons.photo_album_outlined),
                title: const Text('显示私密相册入口'),
                subtitle: Text(privacy.showPrivateAlbums
                    ? '私密相册封面会在首页正常展示'
                    : '入口已隐藏，照片和相册数据仍安全保留'),
                value: privacy.showPrivateAlbums,
                onChanged: (value) =>
                    _togglePrivateAlbums(context, privacy, lock, value),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              'AI 创作',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ClayCard(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('AI 服务'),
              subtitle: const Text('配置 DeepSeek API 和朋友圈文案模型'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              '数据与迁移',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ClayCard(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('完整相册包'),
              subtitle: const Text('导出或恢复全部照片和相册资料'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LibraryBackupPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              '管理',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ClayCard(
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('标签管理'),
              subtitle: const Text('创建、编辑或删除照片标签'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagManagementPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // About section
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              '关于',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ClayCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('版本'),
                  trailing: Text(
                    '1.1.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    AppLockController lock,
    bool enabled,
  ) async {
    if (enabled) {
      final pin = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const PinSetupPage()),
      );
      if (pin != null) await lock.enable(pin);
      return;
    }
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinVerifyPage(title: '关闭应用锁'),
      ),
    );
    if (verified == true) await lock.disable();
  }

  Future<void> _changeAppLockPin(
    BuildContext context,
    AppLockController lock,
  ) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinVerifyPage(title: '验证当前密码'),
      ),
    );
    if (verified != true || !context.mounted) return;
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const PinSetupPage(title: '设置新密码'),
      ),
    );
    if (pin == null) return;
    await lock.changePin(pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('六位密码已修改')),
      );
    }
  }

  Future<void> _togglePrivateAlbums(
    BuildContext context,
    PrivateAlbumController privacy,
    AppLockController lock,
    bool visible,
  ) async {
    if (!lock.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先开启六位密码应用锁，再隐藏私密相册入口')),
      );
      return;
    }
    if (visible) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinVerifyPage(
            title: '显示私密相册',
            subtitle: '请输入应用锁主密码重新显示私密相册入口',
          ),
        ),
      );
      if (verified != true) return;
    }
    await privacy.setShowPrivateAlbums(visible);
  }
}
