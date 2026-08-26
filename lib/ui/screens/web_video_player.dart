// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Generates a thumbnail from an S3 MP4 URL on web using canvas frame capture
class WebThumbnailGenerator {
  static final Map<String, String?> _cache = {};

  static Future<String?> generate(String videoUrl) async {
    if (_cache.containsKey(videoUrl)) return _cache[videoUrl];

    try {
      final completer = html.VideoElement()
        ..src = videoUrl
        ..crossOrigin = 'anonymous'
        ..muted = true
        ..preload = 'metadata'
        ..style.display = 'none';

      html.document.body!.append(completer);

      // Wait for metadata to load
      await completer.onLoadedMetadata.first.timeout(
        const Duration(seconds: 10),
      );

      // Seek to 2 seconds for a good frame
      completer.currentTime = 2.0;
      await completer.onSeeked.first.timeout(const Duration(seconds: 5));

      // Draw frame to canvas
      final canvas = html.CanvasElement(
        width: completer.videoWidth,
        height: completer.videoHeight,
      );
      canvas.context2D.drawImage(completer, 0, 0);
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.7);

      completer.remove();
      _cache[videoUrl] = dataUrl;
      return dataUrl;
    } catch (e) {
      _cache[videoUrl] = null;
      return null;
    }
  }
}

class WebVideoPlayer extends StatefulWidget {
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
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  static const Color _purple = Color(0xFF532A7B);
  late final String _viewId;

  bool get _isYoutube => widget.url.contains('youtu');
  bool get _isMux => widget.url.contains('player.mux.com');
  bool get _isS3 => widget.url.contains('media.hireforcare.com');

  String get _muxId {
    final uri = Uri.tryParse(widget.url);
    return uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
  }

  String get _embedUrl {
    if (_isYoutube) {
      final uri = Uri.tryParse(widget.url);
      String id = '';
      if (uri != null) {
        id = uri.host.contains('youtu.be')
            ? (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '')
            : (uri.queryParameters['v'] ?? '');
      }
      return 'https://www.youtube.com/embed/$id?autoplay=1&rel=0';
    }
    if (_isMux) return 'https://player.mux.com/$_muxId?autoplay=true';
    // S3 MP4 — use HTML5 video tag via data URI
    return widget.url;
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'video-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      if (_isS3) {
        // For S3 MP4 use a video element
        final video = html.VideoElement()
          ..src = widget.url
          ..controls = true
          ..autoplay = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#000'
          ..setAttribute('controlsList', 'nodownload')
          ..setAttribute('playsinline', 'true');
        return video;
      } else {
        // For Mux and YouTube use iframe
        final iframe = html.IFrameElement()
          ..src = _embedUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..setAttribute('allow', 'autoplay; fullscreen; encrypted-media; picture-in-picture');
        return iframe;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(children: [
        // Video player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: HtmlElementView(viewType: _viewId),
        ),

        // Info section
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.date != null && widget.date!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Assigned: ${_formatDate(widget.date)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: _purple.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isYoutube
                          ? 'Playing from YouTube'
                          : _isMux
                              ? 'Streaming therapy video'
                              : 'Playing therapy video',
                      style: TextStyle(fontSize: 12, color: _purple.withOpacity(0.8)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }
}
