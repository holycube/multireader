import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 合规与帮助类静态文档标识与资源路径。
enum LegalDocument {
  termsOfService(
    title: '服务条款',
    assetPath: 'assets/legal/terms_of_service.md',
  ),
  privacyPolicy(
    title: '隐私协议',
    assetPath: 'assets/legal/privacy_policy.md',
  ),
  childrenProtection(
    title: '儿童个人信息保护规则',
    assetPath: 'assets/legal/children_protection.md',
  ),
  personalInfoCollection(
    title: '个人信息收集清单',
    assetPath: 'assets/legal/personal_info_collection.md',
  ),
  thirdPartySharing(
    title: '第三方信息共享清单',
    assetPath: 'assets/legal/third_party_sharing.md',
  ),
  appPermissions(
    title: '应用权限说明',
    assetPath: 'assets/legal/app_permissions.md',
  ),
  permissionManagement(
    title: '权限管理',
    assetPath: 'assets/legal/permission_management.md',
  ),
  personalizedRecommendation(
    title: '个性化推荐说明',
    assetPath: 'assets/legal/personalized_recommendation.md',
  ),
  illegalContentReport(
    title: '违法不良信息举报',
    assetPath: 'assets/legal/illegal_content_report.md',
  ),
  helpFeedback(
    title: '帮助与反馈',
    assetPath: 'assets/legal/help_feedback.md',
  ),
  wordVariantLookup(
    title: '词形查词说明',
    assetPath: 'assets/legal/word_variant_lookup.md',
  );

  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}

/// 应用内静态 Markdown / 纯文本合规页。
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
  });

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(widget.document.assetPath);
      if (!mounted) return;
      setState(() => _content = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法加载文档：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: _error != null
          ? Center(child: Text(_error!))
          : _content == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    _content!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ),
    );
  }
}
