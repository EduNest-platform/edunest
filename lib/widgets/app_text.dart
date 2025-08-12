import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final double? textScaleFactor;

  const AppText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.textScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
      maxLines: maxLines ?? 1,
      overflow: overflow ?? TextOverflow.ellipsis,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      textScaler:
          textScaleFactor != null ? TextScaler.linear(textScaleFactor!) : null,
    );
  }

  // For future: rich text support
  // static Widget rich({required InlineSpan textSpan, ...}) => ...;

  // For future: plain text helper
  static AppText plain(String text, {TextStyle? style}) =>
      AppText(text, style: style);
}
