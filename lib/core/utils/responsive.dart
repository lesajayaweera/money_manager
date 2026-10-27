import 'package:flutter/widgets.dart';

/// Shared responsive rules for the app.
///
/// The supported phone range starts at 392dp and the app supports Android
/// text scaling up to 1.3x without changing the visual structure.
class Responsive {
  static const double minSupportedWidth = 392;
  static const double maxSupportedTextScale = 1.3;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isNarrow(BuildContext context) => width(context) < 412;

  static double textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0).clamp(
            1.0,
            maxSupportedTextScale,
          );

  /// Grows a fixed-height area only as much as the supported text scale needs.
  static double scaledHeight(
    BuildContext context,
    double base, {
    required double extra,
  }) {
    final scale = textScale(context);
    return base + (scale - 1.0) * extra;
  }
}
