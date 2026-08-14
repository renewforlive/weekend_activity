import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// 三欄等寬的興趣選擇器。勾選符號放在圖示左側，避免 FilterChip 預設
/// 的灰色 avatar 圓底讓視覺顯得零散。
class InterestTagSelector extends StatelessWidget {
  const InterestTagSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final Set<InterestTag> selected;
  final ValueChanged<InterestTag> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: InterestTag.values.map((tag) {
            final isSelected = selected.contains(tag);
            return SizedBox(
              width: width,
              height: 44,
              child: Material(
                color: isSelected ? AppColors.soft : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: enabled ? () => onChanged(tag) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.soft,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: AppColors.primaryDark,
                                )
                              : null,
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          tag.icon,
                          size: 17,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tag.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
