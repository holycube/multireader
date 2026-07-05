import 'package:flutter/material.dart';

import '../../../widgets/soft_card.dart';

/// 设置页分组白卡片容器：SoftCard.flat，无描边、无组内 Divider。
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return SoftCard.flat(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
