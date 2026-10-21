import 'package:url_launcher/url_launcher.dart';

class ExternalUrlLauncher {
  const ExternalUrlLauncher._();

  static Uri? buildEmailUri({
    required String mailtoUrl,
    String? subject,
    String? body,
  }) {
    final recipientUri = Uri.tryParse(mailtoUrl.trim());

    if (recipientUri == null ||
        recipientUri.scheme != 'mailto' ||
        recipientUri.path.trim().isEmpty) {
      return null;
    }

    final queryParameters = {
      if (subject != null && subject.trim().isNotEmpty)
        'subject': subject.trim(),
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
    };
    final encodedQuery = queryParameters.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value)}',
        )
        .join('&');

    return Uri(
      scheme: 'mailto',
      path: recipientUri.path,
      query: encodedQuery.isEmpty ? null : encodedQuery,
    );
  }

  static Future<bool> openEmail({
    required String mailtoUrl,
    String? subject,
    String? body,
  }) async {
    final uri = buildEmailUri(
      mailtoUrl: mailtoUrl,
      subject: subject,
      body: body,
    );

    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWebUrl(String value) async {
    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !uri.hasScheme ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      return false;
    }
  }
}
