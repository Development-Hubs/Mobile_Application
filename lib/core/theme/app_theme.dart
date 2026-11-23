import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'palette.dart';

/// One typeface (IBM Plex Sans Arabic) for Arabic and English, a calm light canvas, white cards with hairline
/// borders and maroon as the only strong colour.
class AppTheme {
  const AppTheme._();

  static const font = 'Plex';

  static ThemeData light(Locale locale) => _build(Brightness.light);
  static ThemeData dark(Locale locale) => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final ink = dark ? Colors.white : Palette.ink;
    final ink2 = dark ? const Color(0xFFAAB1C0) : Palette.ink2;
    final line = dark ? Palette.nightLine : Palette.line;
    final card = dark ? Palette.nightCard : Palette.card;
    final canvas = dark ? Palette.night : Palette.canvas;
    final primary = dark ? const Color(0xFFE4708F) : Palette.maroon;

    final scheme = ColorScheme.fromSeed(seedColor: Palette.maroon, brightness: b).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: Palette.gold,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: ink2,
      outline: line,
      outlineVariant: line,
      error: Palette.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: font);
    TextStyle? t(TextStyle? s, double size, FontWeight w, {double h = 1.3, Color? c}) =>
        s?.copyWith(fontSize: size, fontWeight: w, height: h, color: c ?? ink, letterSpacing: 0, fontFamily: font);
    final text = base.textTheme.copyWith(
      displaySmall: t(base.textTheme.displaySmall, 34, FontWeight.w700, h: 1.15),
      headlineMedium: t(base.textTheme.headlineMedium, 28, FontWeight.w700, h: 1.2),
      headlineSmall: t(base.textTheme.headlineSmall, 24, FontWeight.w700, h: 1.25),
      titleLarge: t(base.textTheme.titleLarge, 19, FontWeight.w700),
      titleMedium: t(base.textTheme.titleMedium, 16, FontWeight.w600),
      titleSmall: t(base.textTheme.titleSmall, 15, FontWeight.w600),
      bodyLarge: t(base.textTheme.bodyLarge, 16, FontWeight.w400, h: 1.5),
      bodyMedium: t(base.textTheme.bodyMedium, 14.5, FontWeight.w400, h: 1.5),
      bodySmall: t(base.textTheme.bodySmall, 12.5, FontWeight.w400, h: 1.45, c: ink2),
      labelLarge: t(base.textTheme.labelLarge, 15, FontWeight.w600),
      labelMedium: t(base.textTheme.labelMedium, 13, FontWeight.w500, c: ink2),
    );

    final field = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line));

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: text,
      hintColor: ink2,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: ink,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        hintStyle: TextStyle(color: ink2.withValues(alpha: .7), fontFamily: font),
        labelStyle: TextStyle(color: ink2, fontFamily: font),
        floatingLabelStyle: TextStyle(color: primary, fontFamily: font, fontWeight: FontWeight.w600),
        prefixIconColor: ink2,
        suffixIconColor: ink2,
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(borderSide: BorderSide(color: primary, width: 1.6)),
        errorBorder: field.copyWith(borderSide: const BorderSide(color: Palette.danger)),
        focusedErrorBorder: field.copyWith(borderSide: const BorderSide(color: Palette.danger, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: font),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: line, width: 1.2),
          backgroundColor: card,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: font),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: font)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: line),
        backgroundColor: card,
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w500, fontFamily: font),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: line)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600, fontFamily: font)),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: ink2, titleTextStyle: text.titleSmall, subtitleTextStyle: text.bodySmall),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: .1),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : ink2, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: font,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? primary : ink2,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
