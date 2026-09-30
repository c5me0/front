// Phone and name input variants with v6 typography, focus styling, and keyboard
// behavior.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

enum TextFieldV6Variant { phone, name }

typedef TextFieldV6Metrics = ({
  double height,
  double radius,
  double borderWidth,
  double padding,
  double gap,
  double slotPaddingX,
});

TextFieldV6Metrics textFieldV6Metrics(TextFieldV6Variant variant) =>
    switch (variant) {
      TextFieldV6Variant.phone => (
        height: CameoLayout.textFieldV6PhoneHeight,
        radius: CameoLayout.textFieldV6PhoneRadius,
        borderWidth: CameoLayout.textFieldV6PhoneBorderWidth,
        padding: CameoLayout.textFieldV6PhonePadding,
        gap: CameoLayout.textFieldV6PhoneGap,
        slotPaddingX: CameoLayout.textFieldV6PhoneSlotPaddingX,
      ),
      TextFieldV6Variant.name => (
        height: CameoLayout.textFieldV6NameHeight,
        radius: CameoLayout.textFieldV6NameRadius,
        borderWidth: CameoLayout.textFieldV6NameBorderWidth,
        padding: CameoLayout.textFieldV6NamePadding,
        gap: CameoLayout.textFieldV6NameGap,
        slotPaddingX: CameoLayout.textFieldV6NameSlotPaddingX,
      ),
    };

///

class TextFieldV6 extends StatefulWidget {
  const TextFieldV6({
    super.key,
    required this.variant,
    this.focused = false,
    this.children = const [],
  });

  final TextFieldV6Variant variant;
  final bool focused;

  final List<Widget> children;

  static const Key surfaceKey = ValueKey('textFieldV6.surface');

  static const Key borderKey = ValueKey('textFieldV6.border');

  @override
  State<TextFieldV6> createState() => TextFieldV6State();
}

class TextFieldV6State extends State<TextFieldV6>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focus = AnimationController.unbounded(
    vsync: this,
    value: widget.focused ? 1 : 0,
  );
  bool _reduceMotion = false;

  double get focusProgress => _focus.value;

  @override
  void initState() {
    super.initState();
    _focus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(TextFieldV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused == widget.focused) return;
    final target = widget.focused ? 1.0 : 0.0;
    if (_reduceMotion) {
      _focus.value = target;
    } else {
      _focus.springTo(target, CameoSprings.smooth);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final m = textFieldV6Metrics(widget.variant);
    final bordered = m.borderWidth > 0;
    return SizedBox(
      height: m.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlurSurface(
            key: TextFieldV6.surfaceKey,
            blur: CameoBlur.blur,
            tint: c.backgroundFillNeutralBase,
            radius: m.radius,
            padding: EdgeInsets.symmetric(
              horizontal: m.borderWidth + m.padding,
            ),
            child: Row(spacing: m.gap, children: widget.children),
          ),
          if (bordered)
            IgnorePointer(
              key: TextFieldV6.borderKey,
              child: AnimatedBuilder(
                animation: _focus,
                builder: (context, child) => Opacity(
                  opacity: _focus.value.clamp(0.0, 1.0),
                  child: child,
                ),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(m.radius),
                      side: BorderSide(
                        color: c.staticBlackBase,
                        width: m.borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TextFieldV6Slot extends StatelessWidget {
  const TextFieldV6Slot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.textFieldV6PhoneSlotPaddingX,
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
}
