import 'package:flutter/material.dart';

/// 3J37 Builder 主题令牌：深墨金色体系（与IGotYou一致）
class AppTokens {
  AppTokens._();

  // ── Color roles ──────────────────────────────────────────
  static const Color background    = Color(0xFF1C1B1E);
  static const Color surface       = Color(0xFF2D2A24);
  static const Color surfaceAlt    = Color(0xFF241F1A);
  static const Color primary       = Color(0xFFE0AE40); // gold
  static const Color onPrimary     = Color(0xFF241C07); // dark on gold
  static const Color textPrimary   = Color(0xFFF2E9D6); // warm off-white
  static const Color textSecondary = Color(0xFFB09B74); // muted gold
  static const Color keyOff        = Color(0xFF6F6B60);

  static const Color cardBackground = Color(0xFF2D2A24);
  static const Color cardTitle      = Color(0xFFE0AE40);
  static const Color cardBody       = Color(0xFFF2E9D6);
  static const Color cardMuted      = Color(0xFFB09B74);
  static Color cardBorder          = const Color(0xFFE0AE40).withValues(alpha: 0.4);

  static Color chipBackground      = const Color(0xFF2D2A24).withValues(alpha: 0.92);
  static Color chipForeground      = const Color(0xFFF2E9D6).withValues(alpha: 0.74);
  static const Color chipBorder    = Color(0xFFB09B74);

  static const Color inputBorder   = Color(0xFFD8A84E);
  static Color buttonShadow        = Colors.black.withValues(alpha: 0.16);
  static Color cardShadow          = Colors.black.withValues(alpha: 0.06);
  static Color overlayMask         = Colors.black.withValues(alpha: 0.26);

  // ── Discipline colours (updated) ────────────────────────
  static const Map<String, Color> disciplineColours = {
    'finishing':   Color(0xFF3764B3),
    'shooting':    Color(0xFF61AF57),
    'playmaking':  Color(0xFFE29754),
    'defense':     Color(0xFFDE574B),
    'rebounding':  Color(0xFF9785EA),
    'physicals':   Color(0xFFA27D32),
  };

  // ── Badge tier colours ──────────────────────────────────
  static const Map<String, Color> badgeTierColours = {
    'bronze':       Color(0xFFCD7F32),
    'silver':       Color(0xFFC0C0C0),
    'gold':         Color(0xFFE0AE40),
    'hall_of_fame': Color(0xFF9B59B6),
    'legend':       Color(0xFFFF6B6B),
  };

  // ── Shape ───────────────────────────────────────────────
  static const double radius = 2; // 直角

  // ── Typography ──────────────────────────────────────────
  static const String fontFamily = 'Noto Serif SC';

  static const TextStyle brandMark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: primary,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: cardTitle,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: onPrimary,
  );

  // ── Spacing ─────────────────────────────────────────────
  static const double pageEdge           = 16;
  static const double contentTopInset    = 140;
  static const double contentBottomInset = 236;
  static const double topScrimHeight     = 170;
  static const double bottomScrimHeight  = 160;
  static const double topChromeInset     = 8;

  // ── Animation durations ─────────────────────────────────
  static const Duration animShort  = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 250);
  static const Duration animLong   = Duration(milliseconds: 350);
  static const Duration sidebarIn  = Duration(milliseconds: 340);
  static const Duration bannerIn   = Duration(milliseconds: 240);
  static const Duration bannerOut  = Duration(milliseconds: 200);

  static const Curve curveOut = Curves.easeOutCubic;
  static const Curve curveInOut = Curves.easeInOutCubic;

  // ── Gradients (与IGotYou一致) ───────────────────────────
  static const LinearGradient topScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background,
      Color(0xE61C1B1E),
      Color(0x7A1C1B1E),
      Color(0x001C1B1E),
    ],
    stops: [0.0, 0.34, 0.72, 1.0],
  );

  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      background,
      Color(0xE61C1B1E),
      Color(0x7A1C1B1E),
      Color(0x001C1B1E),
    ],
    stops: [0.0, 0.34, 0.72, 1.0],
  );
}
