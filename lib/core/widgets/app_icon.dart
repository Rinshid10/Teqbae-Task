import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Names of the icons exported from Figma (files in assets/icons/).
/// Using constants means a typo is a compile error, not a blank icon.
abstract final class AppIcons {
  static const navHome = 'nav_home';
  static const navAttendance = 'nav_attendance';
  static const navLeave = 'nav_leave';

  static const arrowBack = 'arrow_back';
  static const arrowForward = 'arrow_forward';
  static const chevronLeft = 'chevron_left';
  static const chevronRight = 'chevron_right';
  static const chevronRightSmall = 'chevron_right_small';
  static const close = 'close';
  static const plus = 'plus';

  static const calendar = 'calendar';
  static const calendarStart = 'calendar_start';
  static const calendarEnd = 'calendar_end';
  static const calendarCheck = 'calendar_check';
  static const clock = 'clock';
  static const clockSmall = 'clock_small';
  static const stopwatch = 'stopwatch';
  static const history = 'history';

  static const login = 'login';
  static const logout = 'logout';
  static const personCheck = 'person_check';

  static const check = 'check';
  static const checkSmall = 'check_small';
  static const checkLarge = 'check_large';
  static const checkCircle = 'check_circle';
  static const errorCircle = 'error_circle';
  static const errorFilled = 'error_filled';
  static const infoCircle = 'info_circle';
  static const shieldCheck = 'shield_check';
  static const shieldAlert = 'shield_alert';
  static const blockCircle = 'block_circle';

  static const cloud = 'cloud';
  static const cloudDone = 'cloud_done';
  static const cloudOff = 'cloud_off';
  static const sync = 'sync';
  static const autoSync = 'auto_sync';
  static const database = 'database';
  static const monitorCheck = 'monitor_check';
  static const refresh = 'refresh';

  static const navigationArrow = 'navigation_arrow';
  static const locationPin = 'location_pin';
  static const locationOff = 'location_off';
  static const locationOutside = 'location_outside';
  static const gpsTarget = 'gps_target';
  static const gpsCrosshair = 'gps_crosshair';
  static const gpsOff = 'gps_off';
  static const radarRings = 'radar_rings';
  static const building = 'building';
  static const officeBuilding = 'office_building';
  static const officeInside = 'office_inside';
  static const lock = 'lock';
  static const tune = 'tune';

  static const umbrella = 'umbrella';
  static const leaveTile = 'leave_tile';
  static const stethoscope = 'stethoscope';
  static const leaf = 'leaf';
  static const notes = 'notes';
  static const factCheck = 'fact_check';
  static const pieChart = 'pie_chart';
  static const send = 'send';
  static const edit = 'edit';

  static const terminal = 'terminal';
  static const code = 'code';
  static const swapArrows = 'swap_arrows';
  static const reset = 'reset';
  static const splashSync = 'splash_sync';
}

/// Draws one of the Figma icons.
///
/// Each SVG already has the size and colour it has in the design, so by
/// default nothing needs to be passed. Give [color] to re-tint an icon (for
/// example the inactive vs active tab), and [size] to scale it.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size, this.color});

  final String name;

  /// Height in logical pixels; the width follows the icon's own proportions.
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      height: size,
      // srcIn keeps the icon's shape and replaces every colour in it.
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      // Decorative: the text next to an icon carries the meaning.
      excludeFromSemantics: true,
    );
  }
}

/// An icon centred on a filled circle or rounded square, e.g. the light-blue
/// circle behind a check mark.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.background,
    this.iconColor,
    this.iconSize,
    this.radius,
  });

  final String icon;
  final double size;
  final Color background;
  final Color? iconColor;
  final double? iconSize;

  /// Null draws a circle; a value draws a rounded square.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      child: AppIcon(icon, color: iconColor, size: iconSize),
    );
  }
}
