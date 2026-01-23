/// Route name constants for app navigation
class Routes {
  // Screen routes
  static const String home = '/';
  static const String vitals = '/vitals';
  static const String clinical = '/clinical';
  static const String connectivity = '/connectivity';
  static const String settings = '/settings';
  static const String profile = '/profile';
  
  // Map of all routes (for easy iteration if needed)
  static const Map<String, String> routeNames = {
    home: 'Home',
    vitals: 'Vitals',
    clinical: 'Clinical',
    connectivity: 'Connectivity',
    settings: 'Settings',
    profile: 'Profile',
  };
}
