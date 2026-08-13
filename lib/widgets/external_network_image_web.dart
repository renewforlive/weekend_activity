import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// On web, use the browser's native image element so external government and
/// venue image hosts that do not send CORS headers can still be displayed.
class ExternalNetworkImage extends StatelessWidget {
  const ExternalNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  static final Set<String> _registeredViewTypes = <String>{};

  @override
  Widget build(BuildContext context) {
    final viewType = 'external-network-image-${url.hashCode.toUnsigned(32)}';
    if (_registeredViewTypes.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (viewId) {
        return web.HTMLImageElement()
          ..src = url
          ..alt = ''
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
      });
    }
    return SizedBox(
      height: height,
      width: width,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
