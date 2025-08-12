import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb and defaultTargetPlatform

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.borderRadius = 10,
    this.padding,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        kIsWeb ||
        [
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ].contains(defaultTargetPlatform);

    final double desktopHeight = 72;
    final double mobileHeight = 56;
    final double desktopTitleSize = 22;
    final double mobileTitleSize = 20;
    final double desktopSubtitleSize = 13;
    final double mobileSubtitleSize = 11;
    final EdgeInsets desktopPadding = const EdgeInsets.fromLTRB(28, 0, 28, 10);
    final EdgeInsets mobilePadding = const EdgeInsets.fromLTRB(12, 0, 12, 8);

    Widget? styledLeading;
    if (leading != null) {
      if (isDesktop) {
        styledLeading = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: AppTheme.primaryBlue),
              child: leading!,
            ),
          ),
        );
      } else {
        styledLeading = leading;
      }
    }
    List<Widget> styledActions = [];
    if (actions != null) {
      styledActions =
          actions!.map((action) {
            if (isDesktop) {
              return Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: AppTheme.primaryBlue),
                    child: action,
                  ),
                ),
              );
            } else {
              return action;
            }
          }).toList();
    }
    return Container(
      padding: isDesktop ? desktopPadding : mobilePadding,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow:
            isDesktop
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        border:
            isDesktop
                ? Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                    width: 2,
                  ),
                )
                : null,
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: SizedBox(
          height: isDesktop ? desktopHeight : mobileHeight,
          child: Row(
            children: [
              if (styledLeading != null) styledLeading,
              if (styledLeading != null) const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize:
                            isDesktop ? desktopTitleSize : mobileTitleSize,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize:
                              isDesktop
                                  ? desktopSubtitleSize
                                  : mobileSubtitleSize,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (styledActions.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: styledActions),
            ],
          ),
        ),
      ),
    );
  }
}
