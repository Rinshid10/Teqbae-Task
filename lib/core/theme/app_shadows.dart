import 'package:flutter/painting.dart';

/// Shadow tokens from the Figma file. Depth is kept very soft: most cards
/// sit almost flat, and only the "today" card, sheets and primary buttons
/// are visibly raised.
abstract final class AppShadows {
  /// Almost flat: list rows, pills, small tiles.
  static const flat = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 1),
  ];

  /// Standard card.
  static const card = [
    BoxShadow(color: Color(0x081A1C1B), offset: Offset(0, 2), blurRadius: 2),
    BoxShadow(color: Color(0x0D1A1C1B), offset: Offset(0, 8), blurRadius: 12),
  ];

  /// The raised "today" card on Home.
  static const raised = [
    BoxShadow(color: Color(0x0D1A1C1B), offset: Offset(0, 8), blurRadius: 12),
  ];

  /// Bottom sheets and floating panels.
  static const sheet = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];

  /// Primary button: a blue-tinted glow underneath.
  static const button = [
    BoxShadow(color: Color(0x3D1E63C7), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// Same button while held down: the glow shrinks, so it looks pushed in.
  static const buttonPressed = [
    BoxShadow(color: Color(0x291E63C7), offset: Offset(0, 1), blurRadius: 4),
  ];

  /// Top bar and bottom navigation.
  static const header = [
    BoxShadow(color: Color(0x08000000), offset: Offset(0, 1), blurRadius: 8),
  ];
  static const nav = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, -1), blurRadius: 12),
  ];
}
