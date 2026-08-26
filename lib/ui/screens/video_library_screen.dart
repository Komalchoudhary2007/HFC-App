import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../services/storage_service.dart';
import 'web_video_player.dart'
    if (dart.library.io) 'web_video_player_stub.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({Key? key}) : super(key: key);

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;
  final Map<String, Uint8List?> _thumbnailCache = {};
  final Map<String, String?> _webThumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<Map<String, String>> _headers() async {
    final token = await StorageService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchVideos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await _headers();
      final user = await StorageService().getUser();
      final userId = user?.id.toString() ?? '';

      if (userId.isEmpty) {
        setState(() { _error = 'Could not get user ID. Please log out and log in again.'; _loading = false; });
        return;
      }

      final recRes = await http.get(
        Uri.parse('$_base/patient/video-recommendations?child_id=$userId'),
        headers: h,
      ).timeout(const Duration(seconds: 15));

      if (recRes.statusCode != 200) {
        setState(() { _error = 'Failed to load recommendations (${recRes.statusCode})'; _loading = false; });
        return;
      }

      final recsBody = jsonDecode(recRes.body);
      final recs = recsBody is List ? recsBody : (recsBody['data'] ?? recsBody['recommendations'] ?? []) as List<dynamic>;

      final ids = recs
          .map((r) => r['video_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (ids.isEmpty) { setState(() { _videos = []; _loading = false; }); return; }

      final vidRes = await http.get(
        Uri.parse('$_base/video-library?ids=${ids.join(',')}'),
        headers: h,
      ).timeout(const Duration(seconds: 15));

      if (vidRes.statusCode != 200) {
        setState(() { _error = 'Failed to load videos (${vidRes.statusCode})'; _loading = false; });
        return;
      }

      final videoList = jsonDecode(vidRes.body) as List<dynamic>;
      final assignedIds = ids.toSet();
      final result = videoList
          .where((v) => assignedIds.contains(v['id']?.toString()))
          .map((v) {
            final rec = recs.firstWhere(
              (r) => r['video_id']?.toString() == v['id']?.toString(),
              orElse: () => <String, dynamic>{},
            );
            return <String, dynamic>{...Map<String, dynamic>.from(v as Map), 'date': rec['date']};
          }).toList();

      setState(() { _videos = result; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  bool _isYoutube(String url) => url.contains('youtu');
  bool _isMux(String url) => url.contains('player.mux.com');
  bool _isS3(String url) => url.contains('media.hireforcare.com');

  String _muxPlaybackId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  }

  String _muxThumbnail(String url) {
    final id = _muxPlaybackId(url);
    if (id.isEmpty) return '';
    return 'https://image.mux.com/$id/thumbnail.jpg?width=600&height=340&fit_mode=smartcrop';
  }

  String _youtubeThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    String id = '';
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } else {
      id = uri.queryParameters['v'] ?? (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '');
    }
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  Future<Uint8List?> _generateS3Thumbnail(String videoUrl) async {
    if (kIsWeb) return null; // handled by _generateWebThumbnail
    if (_thumbnailCache.containsKey(videoUrl)) return _thumbnailCache[videoUrl];
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 600,
        quality: 70,
        timeMs: 2000,
      );
      if (mounted) setState(() => _thumbnailCache[videoUrl] = bytes);
      return bytes;
    } catch (_) {
      _thumbnailCache[videoUrl] = null;
      return null;
    }
  }

  String _getThumbnailUrl(String url) {
    if (_isYoutube(url)) return _youtubeThumbnail(url);
    if (_isMux(url)) return _muxThumbnail(url);
    return '';
  }

  void _openVideo(BuildContext context, Map<String, dynamic> video) {
    final url = video['url']?.toString() ?? '';
    final title = video['title']?.toString() ?? 'Video';
    final date = video['date']?.toString();
    if (kIsWeb) {
      // On web — open in-app iframe player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebVideoPlayer(url: url, title: title, date: date),
        ),
      );
    } else {
      // On mobile — open in-app video_player
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _MobileVideoPlayerPage(video: video)),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text('Video Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null ? _buildError()
          : _videos.isEmpty ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchVideos,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.video_library_outlined, size: 80, color: _purple.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('No Videos Assigned Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Your therapist will assign videos here', style: TextStyle(color: Colors.grey.shade600)),
    ]),
  );

  Widget _buildList() => RefreshIndicator(
    onRefresh: _fetchVideos,
    color: _purple,
    child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      itemBuilder: (_, i) => _buildCard(_videos[i]),
    ),
  );

  Widget _buildCard(Map<String, dynamic> video) {
    final title = video['title']?.toString() ?? 'Untitled';
    final date = video['date']?.toString();
    final url = video['url']?.toString() ?? '';
    final thumbnailUrl = _getThumbnailUrl(url);
    final isS3 = _isS3(url);
    final isYt = _isYoutube(url);

    return GestureDetector(
      onTap: () => _openVideo(context, video),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 180, width: double.infinity,
              child: Stack(alignment: Alignment.center, children: [
                // Thumbnail
                if (isS3 && !kIsWeb)
                  FutureBuilder<Uint8List?>(
                    future: _generateS3Thumbnail(url),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return _buildPlaceholderBg(showSpinner: true);
                      if (snap.data != null) return Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity, height: 180);
                      return _buildPlaceholderBg();
                    },
                  )
                else if (isS3 && kIsWeb)
                  FutureBuilder<String?>(
                    future: WebThumbnailGenerator.generate(url),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return _buildPlaceholderBg(showSpinner: true);
                      if (snap.data != null && snap.data!.isNotEmpty) {
                        return Image.network(snap.data!, fit: BoxFit.cover, width: double.infinity, height: 180,
                            errorBuilder: (_, __, ___) => _buildPlaceholderBg());
                      }
                      return _buildPlaceholderBg();
                    },
                  )
                else if (thumbnailUrl.isNotEmpty)
                  Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover, width: double.infinity, height: 180,
                    loadingBuilder: (_, child, progress) => progress == null ? child : _buildPlaceholderBg(showSpinner: true),
                    errorBuilder: (_, __, ___) => _buildPlaceholderBg(),
                  )
                else
                  _buildPlaceholderBg(),

                // Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x55000000)],
                    ),
                  ),
                ),

                // Play button
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _purple, size: 36),
                ),

                // Badge
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isYt ? Colors.red : _purple,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isYt ? 'YouTube' : 'Video',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (date != null && date.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Assigned: ${_formatDate(date)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openVideo(context, video),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text('Watch Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPlaceholderBg({bool showSpinner = false}) => Container(
    width: double.infinity, height: 180,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_purple.withOpacity(0.15), const Color(0xFF7B4BA8).withOpacity(0.25)],
      ),
    ),
    child: showSpinner
        ? const Center(child: CircularProgressIndicator(color: _purple, strokeWidth: 2))
        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.video_library_rounded, size: 48, color: _purple.withOpacity(0.35)),
            const SizedBox(height: 8),
            Text('Tap to watch', style: TextStyle(fontSize: 12, color: _purple.withOpacity(0.5))),
          ]),
  );
}

// ─── Mobile In-App Video Player ──────────────────────────────────────────────

class _MobileVideoPlayerPage extends StatefulWidget {
  final Map<String, dynamic> video;
  const _MobileVideoPlayerPage({required this.video});

  @override
  State<_MobileVideoPlayerPage> createState() => _MobileVideoPlayerPageState();
}

class _MobileVideoPlayerPageState extends State<_MobileVideoPlayerPage> {
  static const Color _purple = Color(0xFF532A7B);

  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMsg = '';
  bool _showControls = true;

  String get _url => widget.video['url']?.toString() ?? '';
  String get _title => widget.video['title']?.toString() ?? 'Video';
  bool get _isYoutube => _url.contains('youtu');
  bool get _isMux => _url.contains('player.mux.com');

  String get _muxId {
    final uri = Uri.tryParse(_url);
    return uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
  }

  // Try HLS first, fallback to MP4
  String get _hlsUrl => _isMux ? 'https://stream.mux.com/$_muxId.m3u8' : _url;
  String get _mp4Url => _isMux ? 'https://stream.mux.com/$_muxId/high.mp4' : _url;

  @override
  void initState() {
    super.initState();
    if (!_isYoutube) _initPlayer(_hlsUrl);
  }

  Future<void> _initPlayer(String url) async {
    try {
      print('🎬 [Player] Trying: $url');
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {'User-Agent': 'Mozilla/5.0 (Android)'},
      );
      await ctrl.initialize();
      print('🎬 [Player] Success: $url');
      if (mounted) {
        setState(() { _controller = ctrl; _initialized = true; });
        ctrl.play();
      }
    } catch (e) {
      print('🎬 [Player] Failed ($url): $e');
      // If HLS failed and we have an MP4 fallback, try it
      if (_isMux && url == _hlsUrl) {
        print('🎬 [Player] Trying MP4 fallback: $_mp4Url');
        await _initPlayer(_mp4Url);
      } else {
        if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _isYoutube
              ? _buildYoutubeView()
              : _hasError
                  ? _buildError()
                  : !_initialized
                      ? const Center(child: CircularProgressIndicator(color: _purple))
                      : _buildPlayer(),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              if (widget.video['date'] != null)
                Text('Assigned: ${_formatDate(widget.video['date']?.toString())}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildPlayer() {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(alignment: Alignment.center, children: [
        VideoPlayer(_controller!),
        if (_showControls) ...[
          Container(color: Colors.black38),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
              onPressed: () => _controller!.seekTo(_controller!.value.position - const Duration(seconds: 10)),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _purple, size: 40,
                ),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
              onPressed: () => _controller!.seekTo(_controller!.value.position + const Duration(seconds: 10)),
            ),
          ]),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: _purple,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildYoutubeView() {
    final uri = Uri.tryParse(_url);
    String ytId = '';
    if (uri != null) {
      ytId = uri.host.contains('youtu.be')
          ? (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '')
          : (uri.queryParameters['v'] ?? '');
    }
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication),
      child: Stack(alignment: Alignment.center, children: [
        if (ytId.isNotEmpty)
          Image.network('https://img.youtube.com/vi/$ytId/hqdefault.jpg',
              fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900)),
        Container(color: Colors.black54),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 10),
          const Text('Tap to open in YouTube', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: Colors.white54, size: 48),
        const SizedBox(height: 12),
        const Text('Could not load video', style: TextStyle(color: Colors.white70, fontSize: 15)),
        if (_errorMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_errorMsg, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() { _hasError = false; _initialized = false; _errorMsg = ''; });
            _initPlayer(_hlsUrl);
          },
          style: ElevatedButton.styleFrom(backgroundColor: _purple),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),
  );

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }
}
