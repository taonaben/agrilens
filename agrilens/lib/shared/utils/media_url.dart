import 'app_constants.dart';

/// Turns API media paths such as `/media/profile_pics/driver.jpg` into URLs
/// that Flutter can load over the network.
String? resolveMediaUrl(String? value) {
  final path = value?.trim();
  if (path == null || path.isEmpty) return null;

  final uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme && uri.hasAuthority) {
    return uri.toString();
  }

  return Uri.parse(
    AppConstants.apiBaseUrl,
  ).resolve(path.startsWith('/') ? path : '/$path').toString();
}
