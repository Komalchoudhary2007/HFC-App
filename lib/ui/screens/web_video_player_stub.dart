import 'package:flutter/material.dart';

// Stub — WebVideoPlayer and WebThumbnailGenerator are only used on web
class WebThumbnailGenerator {
  static Future<String?> generate(String videoUrl) async => null;
}

class WebVideoPlayer extends StatelessWidget {
  final String url;
  final String title;
  final String? date;

  const WebVideoPlayer({
    Key? key,
    required this.url,
    required this.title,
    this.date,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
