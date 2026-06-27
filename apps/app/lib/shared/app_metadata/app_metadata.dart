const String unknownAppMetadataValue = 'unknown';

class AppBuildMetadata {
  const AppBuildMetadata({
    this.appVersion = unknownAppMetadataValue,
    this.defaultEngineVersion = unknownAppMetadataValue,
  });

  static const AppBuildMetadata current = AppBuildMetadata(
    appVersion: String.fromEnvironment(
      'BRAINIAX_APP_VERSION',
      defaultValue: unknownAppMetadataValue,
    ),
    defaultEngineVersion: String.fromEnvironment(
      'BRAINIAX_DEFAULT_ENGINE_VERSION',
      defaultValue: unknownAppMetadataValue,
    ),
  );

  final String appVersion;
  final String defaultEngineVersion;
}
