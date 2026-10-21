import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Movo';
  static const String appVersion = '1.0.0';

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 300);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(milliseconds: 1000);

  // Padding and Spacing
  static const double paddingXSmall = 4;
  static const double paddingSmall = 8;
  static const double paddingMedium = 12;
  static const double paddingLarge = 16;
  static const double paddingXLarge = 24;
  static const double paddingXXLarge = 32;

  // Border Radius
  static const double borderRadiusSmall = 4;
  static const double borderRadiusMedium = 8;
  static const double borderRadiusLarge = 12;
  static const double borderRadiusXLarge = 20;
  static const double borderRadiusXXLarge = 28;

  // Gap Sizes
  static const double gapXSmall = 4;
  static const double gapSmall = 8;
  static const double gapMedium = 16;
  static const double gapLarge = 24;
  static const double gapXLarge = 32;

  // Icon Sizes
  static const double iconSizeSmall = 16;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
  static const double iconSizeXLarge = 48;

  // Font Sizes
  static const double fontSizeSmall = 12;
  static const double fontSizeMedium = 14;
  static const double fontSizeNormal = 16;
  static const double fontSizeLarge = 18;
  static const double fontSizeXLarge = 20;
  static const double fontSizeXXLarge = 24;
  static const double fontSizeTitle = 32;

  // Progress Indicator Size
  static const double progressIndicatorSizeSmall = 16;
  static const double progressIndicatorSizeMedium = 24;
  static const double progressIndicatorSizeLarge = 32;
  static const double progressIndicatorSizeXLarge = 48;

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration apiReadTimeout = Duration(seconds: 30);

  // HTTP Status Codes
  static const List<int> successStatusCodes = [200, 201, 202, 204];
  static const List<int> clientErrorStatusCodes = [400, 401, 403, 404];
  static const List<int> serverErrorStatusCodes = [500, 502, 503, 504];

  // Empty States
  static const String emptyStateMessage = 'No data available';
  static const String errorMessage = 'Something went wrong';
  static const String loadingMessage = 'Loading...';

  //URL Constants
  static const String helpCenterUrl = 'https://movo.co.zw/help-center/';
  static const String termsAndConditionsUrl =
      'https://movo.co.zw/terms-of-service';
  static const String privacyPolicyUrl = 'https://movo.co.zw/privacy-policy';
  static const String mailtoSupportEmail = 'mailto:support@movo.co.zw';
  static const String supportPhoneNumber = '716633439';

  // API Endpoints
  // Priority: .env -> --dart-define -> default
  static const String _apiBaseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static String get apiBaseUrl {
    final envValue = dotenv.env['API_BASE_URL']?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    if (_apiBaseUrlFromDefine.isNotEmpty) {
      return _apiBaseUrlFromDefine;
    }
    return 'http://10.0.2.2:8000';
  }

  // WebSocket Endpoint
  // Priority: .env -> --dart-define -> default
  static const String _wsBaseUrlFromDefine = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '',
  );
  static String get wsBaseUrl {
    final envValue = dotenv.env['WS_BASE_URL']?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    if (_wsBaseUrlFromDefine.isNotEmpty) {
      return _wsBaseUrlFromDefine;
    }
    final apiUri = Uri.parse(apiBaseUrl);
    return apiUri
        .replace(scheme: apiUri.scheme == 'https' ? 'wss' : 'ws')
        .toString();
  }
}
