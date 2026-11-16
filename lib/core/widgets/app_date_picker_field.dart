import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// White field showing a caption and a date, with a calendar icon. Tapping
/// opens the platform date picker. An error is shown in red underneath.
class AppDatePickerField extends StatelessWidget {
  const AppDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.icon = AppIcons.calendarStart,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;

  /// Receives a date-only value built with DateTime.utc, matching how the
  /// domain layer represents calendar days (see Clock.dateOnly).
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final String icon;
  final String? errorText;
  final bool enabled;

  static final _format = DateFormat('d MMM yyyy');

  Future<void> _pick(BuildContext context) async {
    // The picker asserts that the initial date lies inside the allowed
    // range, so an out-of-range value (e.g. a date that is now in the past)
    // is pulled back to the nearest allowed day.
    var initial = value ?? firstDate;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      onChanged(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          child: PressableScale(
            onTap: enabled ? () => _pick(context) : null,
            child: Container(
              // A minimum, not a fixed height: the field grows with a large
              // system font instead of clipping its two lines.
              constraints: const BoxConstraints(minHeight: 56),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.flat,
                border: hasError
                    ? Border.all(color: AppColors.danger, width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppText.caption
                              .copyWith(color: AppColors.textTertiary),
                        ),
                        Text(
                          value == null
                              ? AppStrings.selectDate
                              : _format.format(value!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.tabular(AppText.value).copyWith(
                            color: value == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(icon),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
