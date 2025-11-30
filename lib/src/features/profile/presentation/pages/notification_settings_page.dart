import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final Map<_NotificationToggle, bool> _values = {
    _NotificationToggle.pushEnabled: true,
    _NotificationToggle.searchMatches: true,
    _NotificationToggle.priceDrops: false,
    _NotificationToggle.newArrivals: true,
    _NotificationToggle.suggestionsDigest: true,
    _NotificationToggle.promotions: false,
  };

  void _toggle(_NotificationToggle key, bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      _values[key] = value;
    });
    // TODO: persist preferences to backend/settings service
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Choose the updates you want to receive',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.6),
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),
              SizedBox(height: spacing.l),
              _SettingsCard(
                children: [
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'Push Notifications',
                    value: _values[_NotificationToggle.pushEnabled] ?? true,
                    onChanged: (val) => _toggle(_NotificationToggle.pushEnabled, val),
                  ),
                  const SizedBox(height: 8),
                  _Divider(),
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'Search Matches',
                    helper: 'When we find styles similar to your search',
                    value: _values[_NotificationToggle.searchMatches] ?? true,
                    onChanged: (val) => _toggle(_NotificationToggle.searchMatches, val),
                  ),
                  const SizedBox(height: 8),
                  _Divider(),
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'Price Drops',
                    value: _values[_NotificationToggle.priceDrops] ?? false,
                    onChanged: (val) => _toggle(_NotificationToggle.priceDrops, val),
                  ),
                  const SizedBox(height: 8),
                  _Divider(),
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'New Arrivals',
                    value: _values[_NotificationToggle.newArrivals] ?? true,
                    onChanged: (val) => _toggle(_NotificationToggle.newArrivals, val),
                  ),
                  const SizedBox(height: 8),
                  _Divider(),
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'Suggestions Digest',
                    helper: 'Occasional curated picks based on your favorites',
                    value:
                        _values[_NotificationToggle.suggestionsDigest] ?? true,
                    onChanged: (val) =>
                        _toggle(_NotificationToggle.suggestionsDigest, val),
                  ),
                  const SizedBox(height: 8),
                  _Divider(),
                  const SizedBox(height: 8),
                  _SettingsRow.toggle(
                    label: 'Promotions',
                    value: _values[_NotificationToggle.promotions] ?? false,
                    onChanged: (val) =>
                        _toggle(_NotificationToggle.promotions, val),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NotificationToggle {
  pushEnabled,
  searchMatches,
  priceDrops,
  newArrivals,
  suggestionsDigest,
  promotions,
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFECECEC),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsRow.toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: 'PlusJakartaSans',
      color: Colors.black,
    );
    final helperStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontFamily: 'PlusJakartaSans',
      color: Colors.black.withOpacity(0.55),
      height: 1.35,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment:
            helper == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textStyle),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(helper!, style: helperStyle),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: const Color(0xFF34C759),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
