/// Global constants shared across the app.
class AppConstants {
  AppConstants._();

  static const fontFamily = 'RobotoCondensed';

  /// Draw outlines around text fields on the card (handy for tuning
  /// coordinates in assets/templates/*.json).
  static const debugGuides = false;

  static const carClasses = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
  static const drives = ['FWD', 'RWD', '4WD'];
  static const tyres = ['Performance', 'Standard', 'All-Surface', 'Off-Road', 'Slick'];

  static const builtInCountries = [
    'DE', 'IT', 'JP', 'US', 'GB', 'FR', 'SE', 'ES', 'NL', 'CZ',
    'AT', 'CH', 'KR', 'CN', 'RU', 'UA', 'AU', 'CA', 'BR', 'IN',
  ];
}
