import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shell_appearance_mixin.dart';

/// 公版书合法渠道与导入教程。
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, this.isTabActive = true});

  final bool isTabActive;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with ShellAppearanceMixin {

  static const _sources = <_BookSource>[
    _BookSource(
      name: 'Project Gutenberg',
      subtitle: '全球最大公版书库，提供数万本免费 EPUB',
      url: 'https://www.gutenberg.org/',
    ),
    _BookSource(
      name: 'Standard Ebooks',
      subtitle: '精心排版的公版经典文学',
      url: 'https://standardebooks.org/',
    ),
  ];

  static const _importSteps = <_ImportStep>[
    _ImportStep(
      title: '下载 EPUB',
      description: '在下方书源网站搜索书名，选择 EPUB 格式并下载到手机。',
      icon: Icons.download_outlined,
    ),
    _ImportStep(
      title: '找到已下载文件',
      description: '在浏览器「下载」记录或系统文件管理器的「下载」文件夹中确认文件。',
      icon: Icons.folder_outlined,
    ),
    _ImportStep(
      title: '导入到本 App',
      description: '返回书架，点击「导入书籍」，从文件管理器选择刚下载的 EPUB 或 TXT。',
      icon: Icons.upload_file_outlined,
    ),
    _ImportStep(
      title: '开始阅读',
      description: '导入成功后书籍会出现在书架，点击封面即可开始阅读。',
      icon: Icons.menu_book_outlined,
    ),
  ];

  @override
  void didUpdateWidget(covariant ResourcesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      onTabActivated();
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：$url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: shellScaffoldColor,
      appBar: AppBar(title: const Text('资源')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '以下均为合法公版书渠道。本 App 不提供书源聚合，仅收录外链供你自行下载。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '公版书渠道',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _sources.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SourceTile(
                    source: _sources[i],
                    onTap: () => _openUrl(context, _sources[i].url),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '如何从浏览器下载并导入',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '按以下步骤将公版书导入书架：',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _importSteps.length; i++)
            _ImportStepTile(step: _importSteps[i], index: i + 1),
        ],
      ),
    );
  }
}

class _BookSource {
  const _BookSource({
    required this.name,
    required this.subtitle,
    required this.url,
  });

  final String name;
  final String subtitle;
  final String url;
}

class _ImportStep {
  const _ImportStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.onTap,
  });

  final _BookSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.public,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(source.name),
      subtitle: Text(source.subtitle),
      trailing: Icon(
        Icons.open_in_new,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _ImportStepTile extends StatelessWidget {
  const _ImportStepTile({
    required this.step,
    required this.index,
  });

  final _ImportStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      step.icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      step.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
