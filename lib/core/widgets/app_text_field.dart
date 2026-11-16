import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';

/// White multi-line text box with a helper line and a live character count
/// underneath (the "Reason" box on the leave form). When [errorText] is set
/// the box gets a red outline and the helper line shows the error.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.maxLines = 3,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final String? helperText;

  /// Inline error. Null = no error. The controller decides; the field only
  /// shows it.
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.flat,
        border: hasError ? Border.all(color: AppColors.danger, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: maxLines,
            maxLines: maxLines,
            maxLength: maxLength,
            onChanged: onChanged,
            style: AppText.input,
            cursorColor: AppColors.brand,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              // The white box above is the field's frame; the TextField
              // itself draws no border, padding or built-in counter.
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: hint,
              hintStyle:
                  AppText.input.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  errorText ?? helperText ?? '',
                  style: AppText.caption.copyWith(
                    color:
                        hasError ? AppColors.danger : AppColors.textTertiary,
                  ),
                ),
              ),
              if (maxLength != null)
                // Rebuilds only this counter as the user types.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => Text(
                    '${value.text.characters.length}/$maxLength',
                    style: AppText.tabular(AppText.caption)
                        .copyWith(color: AppColors.brand),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
