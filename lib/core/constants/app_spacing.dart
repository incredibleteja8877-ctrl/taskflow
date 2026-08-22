/// A single spacing scale for the whole app.
///
/// Task 09 asks for "consistent spacing/typography". The way you get that is
/// to make ad-hoc numbers awkward: nobody writes `AppSpacing.thirteen`, so
/// padding stays on a 4pt grid without anyone having to police it.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Standard page gutter.
  static const double page = md;

  /// Corner radius for cards, sheets and buttons.
  static const double radius = 12;

  /// Above this width we lay out for tablets — two columns, wider gutters.
  /// Task 09 bonus: "tablet layout".
  static const double tabletBreakpoint = 720;
}
