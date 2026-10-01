import 'package:country_picker/country_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../components/settings_v6.dart';
import '../../components/solid_button.dart';
import '../../components/text_field_v6.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../state/international_phone.dart';

class CountryScreen extends StatefulWidget {
  const CountryScreen({super.key, required this.selected});
  final IsoCode selected;

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _countries = CountryService()
      .getAll()
      .where(
        (country) =>
            IsoCode.values.any((iso) => iso.name == country.countryCode),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppContent.of(context).v6.phone;
    final colors = CameoTheme.colorsOf(context);
    final query = _search.text.trim().toLowerCase().replaceFirst('+', '');
    String name(Country country) =>
        country.getTranslatedName(context) ?? country.name;
    final countries =
        _countries
            .where(
              (country) =>
                  query.isEmpty ||
                  name(country).toLowerCase().contains(query) ||
                  country.name.toLowerCase().contains(query) ||
                  country.countryCode.toLowerCase().contains(query) ||
                  callingCode(
                    IsoCode.values.byName(country.countryCode),
                  ).startsWith(query),
            )
            .toList()
          ..sort((a, b) => name(a).compareTo(name(b)));
    return ColoredBox(
      color: colors.backgroundCanvasNeutralStrong,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(CameoSpace.s16),
              child: Row(
                children: [
                  SolidButton(
                    size: SolidButtonSize.md,
                    variant: SolidButtonVariant.gray,
                    icon: CameoIconName.chevronLeft,
                    semanticLabel: AppContent.of(context).common.back,
                    onPress: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: CameoSpace.s12),
                  Expanded(
                    child: CameoText(
                      copy.countryTitle,
                      style: CameoTextStyles.bodyLgStrong,
                      color: colors.foregroundNeutralBase,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CameoSpace.s16),
              child: TextFieldV6(
                variant: TextFieldV6Variant.name,
                focused: _focus.hasFocus,
                children: [
                  TextFieldV6Slot(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (_search.text.isEmpty)
                          IgnorePointer(
                            child: CameoText(
                              copy.countrySearch,
                              style: CameoTextStyles.bodyLg,
                              color: colors.foregroundNeutralSubtle,
                            ),
                          ),
                        Semantics(
                          label: copy.countrySearch,
                          child: EditableText(
                            key: const ValueKey('phone.countrySearch'),
                            controller: _search,
                            focusNode: _focus,
                            style: CameoTextStyles.bodyLg.copyWith(
                              color: colors.foregroundNeutralBase,
                            ),
                            cursorColor: colors.foregroundNeutralBase,
                            backgroundCursorColor:
                                colors.foregroundNeutralSubtle,
                            autocorrect: false,
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CameoSpace.s16),
            Expanded(
              child: countries.isEmpty
                  ? Center(
                      child: CameoText(
                        copy.noCountries,
                        style: CameoTextStyles.bodyMd,
                        color: colors.foregroundNeutralMuted,
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final iso = IsoCode.values.byName(country.countryCode);
                        return Semantics(
                          selected: iso == widget.selected,
                          child: SettingsRowV6(
                            key: ValueKey('phone.country.${iso.name}'),
                            label: name(country),
                            trailing: SettingsRowV6Trailing.value(
                              '+${callingCode(iso)}',
                            ),
                            onPress: () => Navigator.of(context).pop(iso),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
