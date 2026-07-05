import 'package:flutter/material.dart';

import '../../services/app_metadata.dart';
import '../../services/cache_manager.dart';
import '../../services/local_identity.dart';
import '../resources_screen.dart';
import 'legal_document_screen.dart';
import 'local_data_overview_screen.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_list_tile.dart';

/// 更多设置：数据、通用、合规、存储分组列表。
class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen> {
  static const _icpNumber = '京ICP备00000000号-1';

  AppMetadata? _metadata;
  LocalIdentity? _identity;
  int? _cacheBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final identity = await LocalIdentity.load();
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _metadata = AppMetadata.fallback;
    });
    final metadata = await AppMetadata.load();
    if (!mounted) return;
    setState(() => _metadata = metadata);
    final bytes = await CacheManager.calculateCacheBytes();
    if (!mounted) return;
    setState(() => _cacheBytes = bytes);
  }

  Future<void> _refreshCacheSize() async {
    final bytes = await CacheManager.calculateCacheBytes();
    if (!mounted) return;
    setState(() => _cacheBytes = bytes);
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清理临时文件与应用缓存，不会影响书架与词库数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await CacheManager.clearCache();
      await _refreshCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _openLegal(LegalDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: doc),
      ),
    );
  }

  void _showCheckUpdate() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('检查更新'),
        content: const Text('已是最新版本'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _recommendToFriends() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能即将上线')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _metadata;
    final identity = _identity;
    final cacheLabel = _cacheBytes == null
        ? '计算中…'
        : CacheManager.formatBytes(_cacheBytes!);

    if (metadata == null || identity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('更多设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('更多设置')),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('阅读', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              SettingsListTile(
                leading: const Icon(Icons.link_outlined),
                title: '找书与导入',
                subtitle: '合法书源与导入教程',
                showChevron: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ResourcesScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('数据', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              SettingsListTile(
                leading: const Icon(Icons.storage_outlined),
                title: '本地数据概览',
                subtitle: '书架册数与缓存占用',
                showChevron: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LocalDataOverviewScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('通用', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              SettingsListTile(
                leading: const Icon(Icons.help_outline),
                title: '帮助与反馈',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.helpFeedback),
              ),
              SettingsListTile(
                leading: const Icon(Icons.star_outline),
                title: '评价应用',
                trailingText: 'v${metadata.version}',
                showChevron: true,
                onTap: () {},
              ),
              SettingsListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: '检查更新',
                showChevron: true,
                onTap: _showCheckUpdate,
              ),
              SettingsListTile(
                leading: const Icon(Icons.share_outlined),
                title: '推荐给好友',
                showChevron: true,
                onTap: _recommendToFriends,
              ),
              SettingsListTile(
                leading: const Icon(Icons.report_outlined),
                title: '违法不良信息举报',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.illegalContentReport),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('合规', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              SettingsListTile(
                title: '服务条款',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.termsOfService),
              ),
              SettingsListTile(
                title: '隐私协议',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.privacyPolicy),
              ),
              SettingsListTile(
                title: '儿童个人信息保护规则',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.childrenProtection),
              ),
              SettingsListTile(
                title: '个人信息收集清单',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.personalInfoCollection),
              ),
              SettingsListTile(
                title: '第三方信息共享清单',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.thirdPartySharing),
              ),
              SettingsListTile(
                title: '应用权限说明',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.appPermissions),
              ),
              SettingsListTile(
                title: '权限管理',
                showChevron: true,
                onTap: () => _openLegal(LegalDocument.permissionManagement),
              ),
              SettingsListTile(
                title: '个性化推荐说明',
                showChevron: true,
                onTap: () =>
                    _openLegal(LegalDocument.personalizedRecommendation),
              ),
              SettingsListTile(
                title: 'ICP 备案号',
                trailingText: _icpNumber,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('存储', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              SettingsListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: '清除缓存',
                trailing: _clearing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                trailingText: _clearing ? null : cacheLabel,
                showChevron: !_clearing,
                onTap: _clearing ? null : _clearCache,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'ID: ${identity.anonymousId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
