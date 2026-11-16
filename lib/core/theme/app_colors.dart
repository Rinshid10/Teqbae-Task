import 'package:flutter/painting.dart';

/// Colour tokens. Layout, neutrals, amber and red come from the Figma file
/// (REBS workspace screens); the brand and "success" colours were changed
/// from the design's green/teal to blue on request.
///
/// The design defines a light theme only, so these are plain constants:
/// there is no dark variant to switch to. Widgets always use a token from
/// here, never a raw hex value.
abstract final class AppColors {
  // ---- surfaces -----------------------------------------------------------
  /// Page background (warm off-white).
  static const background = Color(0xFFFAF9F6);

  /// Cards and sheets.
  static const surface = Color(0xFFFFFFFF);

  /// Inset panels inside a card (timestamps strip, stats panel).
  static const panel = Color(0xFFF4F3F0);

  /// Neutral fills: icon tiles, segmented-control track, neutral pills.
  static const fill = Color(0xFFEFEEEB);

  /// Slightly darker neutral: avatar placeholder, card underlay, switcher bg.
  static const chip = Color(0xFFE9E8E5);

  /// Hairlines between rows, and the skeleton placeholder colour.
  static const hairline = Color(0xFFEFEEEB);
  static const divider = Color(0xFFE3E2DF);

  /// Muted grey-green: separators, drag handles, inactive dots.
  static const muted = Color(0xFFBDC9C6);

  // ---- text ---------------------------------------------------------------
  static const textPrimary = Color(0xFF1B1C1A);
  static const textSecondary = Color(0xFF3E4947);
  static const textTertiary = Color(0xFF6E7977);

  // ---- brand --------------------------------------------------------------
  /// Deep blue for text, icons and links.
  static const brand = Color(0xFF0B4A8F);

  /// Slightly lighter blue used for filled primary buttons and the active tab.
  static const accent = Color(0xFF1E63C7);

  // ---- status: success / synced / approved ---------------------------------
  static const success = Color(0xFF1558B0); // dots, icons, strong text
  static const successFill = Color(0xFFCFE2FF); // pill background
  static const successText = Color(0xFF114A99); // text on the fill

  // ---- status: warning / pending -------------------------------------------
  static const warning = Color(0xFF734700);
  static const warningFill = Color(0xFFFFDDB8);
  static const warningText = Color(0xFF653E00);
  static const warningStrong = Color(0xFF2A1700);
  static const warningDeep = Color(0xFF945D00); // icon circle on amber
  static const warningOnDeep = Color(0xFFFFE6CC);

  // ---- status: danger / rejected -------------------------------------------
  static const danger = Color(0xFFBA1A1A);
  static const dangerFill = Color(0xFFFFDAD6);
  static const dangerStrong = Color(0xFF93000A);

  /// Dim layer behind bottom sheets.
  static const scrim = Color(0x662F312F);
}
