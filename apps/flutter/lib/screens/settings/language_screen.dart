import 'package:flutter/widgets.dart';

import '../../components/account_flow_scaffold.dart';
import '../../components/settings_v6.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/cameo_nav.dart';
import '../../state/app_language.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _select(
    AppLanguageController controller,
    AppLanguage language,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await controller.select(language);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageScope.maybeOf(context);
    final copy = AppContent.of(context).v6.settings;
    final colors = CameoTheme.colorsOf(context);
    return AccountFlowScaffold(
      title: copy.language,
      onBack: () => CameoNav.pop(context),
      busy: _saving,
      footer: const SizedBox.shrink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoSpace.s24,
        children: [
          CameoText(
            copy.languageDescription,
            style: CameoTextStyles.bodyLg,
            color: colors.foregroundNeutralMuted,
          ),
          SettingsCard(
            children: [
              for (final language in AppLanguage.values)
                Semantics(
                  selected: controller?.language == language,
                  child: SettingsRowV6(
                    key: ValueKey('language.${language.code}'),
                    label: language.label,
                    icon: controller?.language == language
                        ? CameoIconName.check
                        : null,
                    onPress: controller == null || _saving
                        ? null
                        : () => _select(controller, language),
                  ),
                ),
            ],
          ),
          if (_failed)
            Semantics(
              liveRegion: true,
              child: CameoText(
                copy.languageSaveError,
                style: CameoTextStyles.bodyMd,
                color: colors.systemRed,
              ),
            ),
        ],
      ),
    );
  }
}
