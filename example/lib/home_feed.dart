import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
import 'package:sensitive_content_analysis_example/main.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NSFW Feed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: AuthenticatedAlbumFeed(),
    );
  }
}

class AuthenticatedAlbumFeed extends StatefulWidget {
  const AuthenticatedAlbumFeed({super.key});

  @override
  State<AuthenticatedAlbumFeed> createState() => _AuthenticatedAlbumFeedState();
}

class _AuthenticatedAlbumFeedState extends State<AuthenticatedAlbumFeed> {
  late Future<List<dynamic>> _albumImagesFuture;

  @override
  void initState() {
    super.initState();
    _albumImagesFuture = fetchAlbumImages();
  }

  Future<List<dynamic>> fetchAlbumImages() async {
    try {
      final Uri url = Uri.parse(
          'https://api.waifu.im/images?isNsfw=All&orderBy=Random&page=1&pageSize=30');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['items'] ?? [];
      } else {
        debugPrint('API Error: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Network error fetching album: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _albumImagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('No images found or configuration invalid.'));
        }

        final imagesList = snapshot.data!;

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView.builder(
              itemCount: imagesList.length,
              itemBuilder: (context, index) {
                final imageItem = imagesList[index];
                return AlbumFeedPost(imageData: imageItem, index: index);
              },
            ),
          ),
        );
      },
    );
  }
}

class AlbumFeedPost extends StatefulWidget {
  final Map<String, dynamic> imageData;
  final int index;
  const AlbumFeedPost(
      {super.key, required this.imageData, required this.index});

  // Fixed type signature to accept dynamic map values
  static final Map<String, Map<String, dynamic>> _analysisCache = {};

  @override
  State<AlbumFeedPost> createState() => _AlbumFeedPostState();
}

class _AlbumFeedPostState extends State<AlbumFeedPost> {
  bool _isNsfw = false;
  bool _isBlurred = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    analyzeImage();
  }

  Future<void> analyzeImage() async {
    final String? url = widget.imageData["url"];
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _hasLoaded = true);
      return;
    }

    if (AlbumFeedPost._analysisCache.containsKey(url)) {
      debugPrint("Fetching $url from cache.");
      final cachedData = AlbumFeedPost._analysisCache[url]!;
      if (mounted) {
        setState(() {
          _isNsfw = cachedData['isNsfw'] ?? false;
          _isBlurred = cachedData['isBlurred'] ?? false;
          _hasLoaded = true;
        });
      }
      return;
    }

    try {
      SensitivityAnalysisResult? isSensitive =
          await sca.analyzeNetworkImage(url: url);

      debugPrint(isSensitive?.isSensitive.toString());
      debugPrint(isSensitive?.detectedTypes.toString());

      final bool isNsfw = isSensitive?.isSensitive ?? false;

      AlbumFeedPost._analysisCache[url] = <String, dynamic>{
        'isNsfw': isNsfw,
        'isBlurred': isNsfw,
      };

      if (mounted) {
        setState(() {
          _isNsfw = isNsfw;
          _isBlurred = isNsfw;
        });
      }
    } catch (e, st) {
      debugPrint(e.toString());
      debugPrint(st.toString());

      AlbumFeedPost._analysisCache[url] = <String, dynamic>{
        'isNsfw': false,
        'isBlurred': false,
      };
    } finally {
      if (mounted) setState(() => _hasLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.imageData['url'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              const CircleAvatar(radius: 16, backgroundColor: Colors.indigo),
              const SizedBox(width: 10),
              Text('creator',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            if (!_isNsfw) return;
            setState(() => _isBlurred = !_isBlurred);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              _hasLoaded
                  ? AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: 440,
                        fit: BoxFit.cover,
                      ))
                  : Center(child: CircularProgressIndicator()),
              if (_isBlurred) ...[
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                      child:
                          Container(color: Colors.black.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.white, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'Image Content Restricted\nTap to show the image',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.favorite_border), onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.bookmark_border), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
