// Onboarding profile-name entry. Live sessions advance to partner setup;
// cancelling the authentication flow signs out.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/solid_cta.dart';
import '../../components/text_field_v6.dart';
import '../../components/text_input_gestures.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/session.dart';
import '../../api/api_error_text.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Key fieldKey = ValueKey('profile.field');
  static const Key inputKey = ValueKey('profile.input');
  static const Key placeholderKey = ValueKey('profile.placeholder');
  static const Key ctaKey = ValueKey('profile.cta');

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _editableTextKey = GlobalKey<EditableTextState>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'profile.name');
  Timer? _typing;
  bool _saving = false;
  String? _error;
  final List<VoidCallback> _unregisterFlow = [];

  bool get _valid => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _unregisterFlow
      ..add(FlowDemo.register(FlowDemoAction.profileType, _typeDemo))
      ..add(FlowDemo.register(FlowDemoAction.profileSubmit, _submitFromDemo));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && CameoNav.isTop(context)) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final unregister in _unregisterFlow) {
      unregister();
    }
    _typing?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool _submit() {
    if (!mounted || !_valid || _saving || !CameoNav.isTop(context)) {
      return false;
    }
    _save();
    return true;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).setName(_controller.text.trim());
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorText(error, copy: AppContent.of(context));
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _focus.unfocus();
    if (SessionScope.read(context).usesBackend) return;
    CameoNav.openPartner(context).then((_) {
      if (mounted && CameoNav.isTop(context)) _focus.requestFocus();
    });
  }

  bool _submitFromDemo() => _submit();

  Future<void> _back() async {
    if (!mounted || !CameoNav.isTop(context)) return;
    _focus.unfocus();
    try {
      await SessionScope.read(context).signOutFromServer();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorText(error, copy: AppContent.of(context)),
        );
      }
    }
  }

  bool _typeDemo() {
    if (!mounted || _typing != null || !CameoNav.isTop(context)) return false;
    final target = AppContent.of(context).demo.name.characters.toList();
    var i = 0;
    void typeNext() {
      if (!mounted) return;
      final text = target.take(i + 1).join();
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      i++;
      if (i >= target.length) {
        _typing?.cancel();
        _typing = null;
        FlowDemo.settle(FlowDemoAction.profileType);
      }
    }

    _typing = Timer.periodic(
      Duration(milliseconds: AppContent.of(context).demo.typeIntervalMs),
      (_) => typeNext(),
    );
    typeNext();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final profile = LabV6.of(context).profile;
    final empty = _controller.text.isEmpty;
    return AuthScaffold(
      title: profile.title,
      subtitle: profile.subtitle,
      subtitleWidget: _error == null
          ? null
          : Semantics(
              liveRegion: true,
              child: CameoText(
                _error!,
                style: CameoTextStyles.bodyMd,
                color: c.systemRed,
              ),
            ),
      onBack: _back,
      footerRidesKeyboard: true,
      footer: SolidCta(
        key: ProfileScreen.ctaKey,
        label: profile.cta,
        enabled: _valid,
        busy: _saving,
        onPress: _submit,
      ),
      child: TextInputGestures(
        editableTextKey: _editableTextKey,
        child: TextFieldV6(
          key: ProfileScreen.fieldKey,
          variant: TextFieldV6Variant.name,
          focused: true,
          children: [
            TextFieldV6Slot(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  IgnorePointer(
                    key: const ValueKey('profile.placeholderLayer'),
                    child: ExcludeSemantics(
                      child: AnimatedOpacity(
                        opacity: empty ? 1 : 0,
                        duration: CameoMotion.durationFast,
                        curve: CameoMotion.easingStandard,
                        child: CameoText(
                          profile.placeholder,
                          key: ProfileScreen.placeholderKey,
                          style: CameoTextStyles.bodyLg,
                          color: c.foregroundNeutralSubtle,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    key: const ValueKey('profile.inputLayer'),
                    label: profile.placeholder,
                    child: KeyedSubtree(
                      key: ProfileScreen.inputKey,
                      child: EditableText(
                        key: _editableTextKey,
                        rendererIgnoresPointer: true,
                        controller: _controller,
                        focusNode: _focus,
                        maxLines: 1,
                        autocorrect: false,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,

                        keyboardAppearance: Brightness.light,
                        autofillHints: const [AutofillHints.name],
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppContent.of(context).profile.maxLength,
                          ),
                        ],
                        style: CameoTextStyles.bodyLg.copyWith(
                          color: c.foregroundNeutralBase,
                        ),
                        strutStyle: cameoStrutOf(CameoTextStyles.bodyLg),
                        cursorColor: c.foregroundNeutralBase,
                        backgroundCursorColor: c.foregroundNeutralSubtle,
                        selectionColor: c.backgroundFillNeutralStrong,

                        onEditingComplete: () {},
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
