import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_metadata.dart';

final appBuildMetadataProvider = Provider<AppBuildMetadata>((ref) {
  return AppBuildMetadata.current;
});
