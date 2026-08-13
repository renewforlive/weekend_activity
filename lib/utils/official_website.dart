import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens official venue pages in a browser tab on web, where WebView is not
/// available. Native apps retain the supplied in-app WebView page.
Future<void> openOfficialWebsite(
  BuildContext context, {
  required String url,
  required WidgetBuilder nativePageBuilder,
}) async {
  if (!kIsWeb) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: nativePageBuilder));
    return;
  }

  final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('無法開啟官方網站，請稍後再試。')));
  }
}
