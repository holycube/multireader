import 'package:flutter/material.dart';

import '../../app.dart';
import 'choose_step.dart';
import 'confirm_step.dart';
import 'vocab_selection.dart';
import 'welcome_step.dart';

/// 词库冷启动 3 步向导（任务 #15）。
class VocabWizardScreen extends StatefulWidget {
  const VocabWizardScreen({super.key});

  static const routeName = '/vocab-wizard';

  @override
  State<VocabWizardScreen> createState() => _VocabWizardScreenState();
}

class _VocabWizardScreenState extends State<VocabWizardScreen> {
  int _step = 0;
  VocabSelection? _selection;

  void _goToMainShell() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.mainShell);
  }

  void _onSelectionReady(VocabSelection selection) {
    setState(() {
      _selection = selection;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_step) {
            0 => WelcomeStep(
                key: const ValueKey('welcome'),
                onStart: () => setState(() => _step = 1),
                onSkip: _goToMainShell,
              ),
            1 => ChooseStep(
                key: const ValueKey('choose'),
                onSelectionReady: _onSelectionReady,
                onBack: () => setState(() => _step = 0),
              ),
            _ => ConfirmStep(
                key: const ValueKey('confirm'),
                selection: _selection!,
                onComplete: _goToMainShell,
                onBack: () => setState(() => _step = 1),
              ),
          },
        ),
      ),
    );
  }
}
