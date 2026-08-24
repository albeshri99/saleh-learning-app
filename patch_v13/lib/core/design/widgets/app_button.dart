import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// زر أساسي كبير مستدير بمظهر ثلاثي الأبعاد قابل للضغط —
/// تدرج عمودي بلونين + حافة سفلية داكنة + ظل مزدوج. مناسب لأصابع الأطفال.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.shadowColor = AppColors.primaryDark,
    this.minWidth = 160,
    this.minHeight = AppSpacing.childTouchTarget,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    this.iconSize = 28,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color shadowColor;
  final double minWidth;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.buttonRadius,
        elevation: 0,
        child: Ink(
          decoration: BoxDecoration(
            // تدرج عمودي بلونين: وجه فاتح أعلى ينحدر إلى اللون الأساسي
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, 0.22) ?? color,
                color,
              ],
            ),
            borderRadius: AppSpacing.buttonRadius,
            boxShadow: [
              // الحافة السفلية الداكنة — تأثير 3D قابل للضغط
              BoxShadow(color: shadowColor, offset: const Offset(0, 4)),
              // ظل قريب حاد — تلامس
              const BoxShadow(
                color: Color(0x336B4E3D),
                offset: Offset(0, 6),
                blurRadius: 4,
              ),
              // ظل بعيد ناعم — ارتفاع
              const BoxShadow(
                color: Color(0x226B4E3D),
                offset: Offset(0, 12),
                blurRadius: 18,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: AppSpacing.buttonRadius,
            onTap: onPressed,
            child: Container(
              constraints: BoxConstraints(
                minHeight: minHeight,
                minWidth: minWidth,
              ),
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: iconSize),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label, style: textStyle ?? AppTypography.button),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر إجراءات الدرس الموحد: مقاس ثابت وصغير مع مساحة تحفظ الظل السفلي.
/// تستخدمه كل المشاهد حتى لا يقفز الزر أو يُقص باختلاف المحتوى.
class LessonActionButton extends StatelessWidget {
  const LessonActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Transform.translate(
      offset: Offset(0, compact ? 20 : 24),
      child: SizedBox(
        height: compact ? 48 : 58,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AppButton(
            label: label,
            icon: icon,
            // العرض نفسه لكل عبارات الدرس، ومطابق لزر «السؤال التالي».
            minWidth: 190,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// زر دائري صغير (صوت / ميكروفون / إغلاق).
class AppRoundIconButton extends StatelessWidget {
  const AppRoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.accentBlue,
    this.size = AppSpacing.childTouchTarget,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.22) ?? color, color],
          ),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(color, Colors.black, 0.28) ?? color,
              offset: const Offset(0, 3),
            ),
            const BoxShadow(
              color: Color(0x2A6B4E3D),
              offset: Offset(0, 7),
              blurRadius: 10,
            ),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.55),
          ),
        ),
      ),
    );
  }
}

