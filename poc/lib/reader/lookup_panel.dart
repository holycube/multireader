import 'package:flutter/material.dart';

import '../vocab/dict_lookup_result.dart';
import 'lookup_card.dart';
import 'lookup_variant_card.dart';
import 'reader_preferences.dart';

/// 查词面板用户操作（语义映射在 [ReaderScreen._handleLookupAction]）。
enum LookupAction {
  dontKnow,
  know,
}

/// 当前块是否需要重绘高亮（无视觉变化时跳过）。
bool lookupActionNeedsRedraw(LookupAction action, bool isUnknown) {
  switch (action) {
    case LookupAction.dontKnow:
      return !isUnknown;
    case LookupAction.know:
      return isUnknown;
  }
}

/// 居中查词卡入口：展示释义与按词状态切换的操作按钮。
class LookupPanel {
  LookupPanel._();

  static Future<void> show({
    required BuildContext context,
    required DictLookupResult lookupResult,
    required bool Function(String word) isUnknownFor,
    ReaderPreferences? preferences,
    required Future<void> Function(LookupAction action, String activeWord)
        onAction,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭查词',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final card = lookupResult.hasVariantTabs
            ? LookupVariantCard(
                lookupResult: lookupResult,
                isUnknownFor: isUnknownFor,
                preferences: preferences,
                onAction: onAction,
              )
            : LookupCard(
                word: lookupResult.tappedWord,
                entry: lookupResult.entry,
                isUnknown: isUnknownFor(lookupResult.tappedWord),
                preferences: preferences,
                onAction: (action) =>
                    onAction(action, lookupResult.tappedWord),
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              behavior: HitTestBehavior.opaque,
            ),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: card,
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}
