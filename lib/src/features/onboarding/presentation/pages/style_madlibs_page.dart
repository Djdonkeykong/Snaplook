import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'gender_selection_page.dart';

class StyleMadLibsPage extends StatefulWidget {
  const StyleMadLibsPage({super.key});

  @override
  State<StyleMadLibsPage> createState() => _StyleMadLibsPageState();
}

class _StyleMadLibsPageState extends State<StyleMadLibsPage> {
  static const _styleOptions = [
    'Streetwear',
    'Minimal',
    'Smart casual',
    'Vintage',
    'Sporty',
    'Preppy',
    'Avant-garde',
  ];

  static const _focusOptions = [
    'Outfits',
    'Accessories',
    'Inspiration',
    'Workwear',
    'Travel',
  ];

  static const _priceOptions = [
    'Affordable',
    'Mid-range',
    'Premium',
    'Mix it up',
  ];

  final Set<String> _selectedStyles = {'Streetwear', 'Minimal'};
  String _selectedFocus = 'Outfits';
  String _selectedPrice = 'Affordable';

  Color get _accentColor {
    if (_selectedStyles.isEmpty) return const Color(0xFFE8ECF1);
    final first = _selectedStyles.first;
    switch (first) {
      case 'Streetwear':
        return const Color(0xFFEEF3FF);
      case 'Minimal':
        return const Color(0xFFF3F3F3);
      case 'Smart casual':
        return const Color(0xFFEFF4ED);
      case 'Vintage':
        return const Color(0xFFF8F1EA);
      case 'Sporty':
        return const Color(0xFFE9F4FF);
      case 'Preppy':
        return const Color(0xFFF0F2FF);
      case 'Avant-garde':
        return const Color(0xFFF2EDF7);
      default:
        return const Color(0xFFE8ECF1);
    }
  }

  Color get _accentShadow => Colors.black.withOpacity(0.06);

  Future<void> _openSelector({
    required String title,
    required List<String> options,
    required bool allowMultiple,
    required Set<String> initialSelection,
    required void Function(Set<String>) onSave,
  }) async {
    final Set<String> tempSelection = {...initialSelection};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final spacing = context.spacing;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.l,
                spacing.l,
                spacing.l,
                MediaQuery.of(context).viewInsets.bottom + spacing.l,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  SizedBox(height: spacing.m),
                  Wrap(
                    spacing: spacing.s,
                    runSpacing: spacing.s,
                    children: options.map((option) {
                      final isSelected = tempSelection.contains(option);
                      return ChoiceChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (_) {
                          setModalState(() {
                            if (allowMultiple) {
                              if (isSelected) {
                                tempSelection.remove(option);
                              } else {
                                tempSelection.add(option);
                              }
                            } else {
                              tempSelection
                                ..clear()
                                ..add(option);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF101010),
                        backgroundColor: const Color(0xFFF5F6F7),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: spacing.l),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onSave(tempSelection);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFf2003c),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.s),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  void _onStylesTap() {
    _openSelector(
      title: 'Styles',
      options: _styleOptions,
      allowMultiple: true,
      initialSelection: _selectedStyles,
      onSave: (value) {
        if (value.isEmpty) {
          value.add('Streetwear');
        }
        setState(() {
          _selectedStyles
            ..clear()
            ..addAll(value);
        });
      },
    );
  }

  void _onFocusTap() {
    _openSelector(
      title: 'What are you looking for?',
      options: _focusOptions,
      allowMultiple: false,
      initialSelection: {_selectedFocus},
      onSave: (value) => setState(
          () => _selectedFocus = value.isEmpty ? _selectedFocus : value.first),
    );
  }

  void _onPriceTap() {
    _openSelector(
      title: 'Brand range',
      options: _priceOptions,
      allowMultiple: false,
      initialSelection: {_selectedPrice},
      onSave: (value) => setState(
          () => _selectedPrice = value.isEmpty ? _selectedPrice : value.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    final size = MediaQuery.of(context).size;
    final double mannequinHeight = size.height * 0.38;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: mannequinHeight,
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _accentShadow,
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeOut,
                      child: Container(
                        key: ValueKey(
                            '${_selectedStyles.join(',')}-${_selectedFocus}-${_selectedPrice}'),
                        padding: EdgeInsets.all(spacing.l),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 180,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(spacing.m),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white,
                                              _accentColor.withOpacity(0.6),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: SizedBox(
                                      width: 140,
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.7),
                                          BlendMode.srcATop,
                                        ),
                                        child: Image.asset(
                                          'assets/images/mannequin.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: spacing.m),
                            Text(
                              _selectedStyles.join(' · '),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                                color: Colors.black,
                                fontFamily: 'PlusJakartaSans',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              'Focus: $_selectedFocus • ${_selectedPrice} brands',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontFamily: 'PlusJakartaSans',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Make Snaplook feel like you',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    const Text(
                      'Finish the sentence below',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: spacing.l),
                    _MadLibSentence(
                      stylesLabel: _selectedStyles.isEmpty
                          ? 'Select styles'
                          : _selectedStyles.join(' · '),
                      focusLabel: _selectedFocus,
                      priceLabel: _selectedPrice,
                      onStylesTap: _onStylesTap,
                      onFocusTap: _onFocusTap,
                      onPriceTap: _onPriceTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GenderSelectionPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Looks good',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MadLibSentence extends StatelessWidget {
  final String stylesLabel;
  final String focusLabel;
  final String priceLabel;
  final VoidCallback onStylesTap;
  final VoidCallback onFocusTap;
  final VoidCallback onPriceTap;

  const _MadLibSentence({
    required this.stylesLabel,
    required this.focusLabel,
    required this.priceLabel,
    required this.onStylesTap,
    required this.onFocusTap,
    required this.onPriceTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final chipPadding = EdgeInsets.symmetric(
      horizontal: spacing.s,
      vertical: spacing.xs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            const _SentenceText('I’m into'),
            _MadLibField(
              label: stylesLabel,
              onTap: onStylesTap,
              padding: chipPadding,
              dense: true,
            ),
            const _SentenceText('and'),
            _MadLibField(
              label: stylesLabel.contains('·')
                  ? stylesLabel.split('·').last.trim()
                  : stylesLabel,
              onTap: onStylesTap,
              padding: chipPadding,
              dense: true,
            ),
            const _SentenceText('styles,'),
          ],
        ),
        SizedBox(height: spacing.s),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            const _SentenceText('mostly looking for'),
            _MadLibField(
              label: focusLabel,
              onTap: onFocusTap,
              padding: chipPadding,
              dense: true,
            ),
            const _SentenceText('from'),
            _MadLibField(
              label: '$priceLabel brands',
              onTap: onPriceTap,
              padding: chipPadding,
              dense: true,
            ),
            const _SentenceText('.'),
          ],
        ),
      ],
    );
  }
}

class _MadLibField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final bool dense;

  const _MadLibField({
    required this.label,
    required this.onTap,
    required this.padding,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: dense ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceText extends StatelessWidget {
  final String text;

  const _SentenceText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
