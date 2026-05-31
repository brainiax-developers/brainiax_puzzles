enum AppFlavor { dev, staging, prod }

class AppEnvironment {
  const AppEnvironment._();

  static const String flavorName = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'prod',
  );

  static AppFlavor get flavor {
    switch (flavorName) {
      case 'dev':
        return AppFlavor.dev;
      case 'staging':
        return AppFlavor.staging;
      default:
        return AppFlavor.prod;
    }
  }

  static bool get isProduction => flavor == AppFlavor.prod;
}
