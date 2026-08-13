import 'package:flutter/material.dart';

/// Native platforms can fetch external images directly.
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

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    height: height,
    width: width,
    fit: fit,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
