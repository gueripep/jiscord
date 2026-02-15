import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:fluffychat/config/setting_keys.dart';

class UrlPreview extends StatefulWidget {
  final String url;
  final Color? textColor;
  final double borderRadius;

  const UrlPreview({
    super.key,
    required this.url,
    this.textColor,
    this.borderRadius = 12.0,
  });

  @override
  State<UrlPreview> createState() => _UrlPreviewState();
}

class _UrlPreviewState extends State<UrlPreview> {
  // Simple in-memory cache for the session
  static final Map<String, LinkMetadata?> _cache = {};

  late Future<LinkMetadata?> _metadataFuture;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  bool _isInitializing = false;
  String? _error;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _metadataFuture = _fetchMetadata();
  }

  Future<LinkMetadata?> _fetchMetadata() async {
    if (_cache.containsKey(widget.url)) {
      return _cache[widget.url];
    }

    try {
      final uri = Uri.tryParse(widget.url);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        return null; // Don't try to fetch non-http URLs
      }

      // Check persistent cache
      final storedJson = AppSettings.store.getString(
        'url_preview_cache_${widget.url}',
      );
      if (storedJson != null) {
        try {
          final metadata = LinkMetadata.fromJson(jsonDecode(storedJson));
          _cache[widget.url] = metadata;
          return metadata;
        } catch (e) {
          debugPrint('Error decoding cached metadata: $e');
        }
      }

      // Special handling for Twitter/X and proxies (fxtwitter, vxtwitter, fixupx, etc.)
      if (uri.host.contains('twitter.com') ||
          uri.host.contains('x.com') ||
          uri.host.contains('fixupx.com')) {
        try {
          // Force use of api.fxtwitter.com as the canonical API endpoint
          const apiAuthority = 'api.fxtwitter.com';
          final path = uri.path
              .replaceAll('/i/', '/')
              .replaceAll('/i/status/', '/status/');
          // Ensure we don't have double slashes or missing status

          final apiUri = Uri.https(apiAuthority, path);

          final response = await http.get(
            apiUri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
            },
          );

          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('text/html') ||
              response.body.trim().startsWith('<!DOCTYPE')) {
            throw FormatException('Received HTML instead of JSON');
          }

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            final tweet = json['tweet'];
            if (tweet != null) {
              String? startImage;
              String? videoUrl;

              if (tweet['media'] != null) {
                final media = tweet['media'];
                if (media['videos'] != null &&
                    (media['videos'] as List).isNotEmpty) {
                  startImage = media['videos'][0]['thumbnail_url'];
                  // Get the highest bitrate video URL
                  final variants = media['videos'][0]['variants'] as List?;
                  if (variants != null) {
                    final videoVariant = variants
                        .where((v) => v['content_type'] == 'video/mp4')
                        .toList();
                    // Sort by bitrate descending
                    videoVariant.sort(
                      (a, b) =>
                          (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0),
                    );
                    if (videoVariant.isNotEmpty) {
                      videoUrl = videoVariant.first['url'];
                    }
                  } else {
                    videoUrl = media['videos'][0]['url'];
                  }
                } else if (media['photos'] != null &&
                    (media['photos'] as List).isNotEmpty) {
                  startImage = media['photos'][0]['url'];
                } else if (media['mosaic'] != null) {
                  // Some proxies use mosaic
                  startImage = media['mosaic']['formats']?['jpeg'];
                }
              }

              final metadata = LinkMetadata(
                title:
                    '${tweet['author']?['name']} (@${tweet['author']?['screen_name']})',
                description: tweet['text'],
                imageUrl: startImage,
                videoUrl: videoUrl,
                siteName: 'FxTwitter', // Or dynamic based on host
                url: widget.url,
                themeColor: const Color(0xFF1DA1F2), // Twitter Blue
              );
              _saveToCache(metadata);
              return metadata;
            }
          }
        } catch (e) {
          debugPrint('FixTweet API failed, falling back to scraping: $e');
        }
      }

      // Special handling for Instagram / KKInstagram
      if (uri.host.contains('instagram.com') ||
          uri.host.contains('kkinstagram.com')) {
        try {
          final isReel = uri.path.contains('/reel/');
          final id = uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );

          if (id.isNotEmpty) {
            final instaUri = Uri.https('www.instagram.com', uri.path);

            // Fetch metadata from Instagram directly using Twitterbot UA
            final metadataResponse = await http
                .get(instaUri, headers: {'User-Agent': 'Twitterbot/1.0'})
                .timeout(const Duration(seconds: 5));

            if (metadataResponse.statusCode == 200) {
              final document = parser.parse(metadataResponse.body);
              final metadata = _extractMetadata(document, instaUri);

              if (metadata != null) {
                // If it's a reel, use kkinstagram as the video source
                String? videoUrl;
                if (isReel) {
                  videoUrl = 'https://kkinstagram.com${uri.path}';
                }

                final finalMetadata = LinkMetadata(
                  title: metadata.title,
                  description: metadata.description,
                  imageUrl: metadata.imageUrl,
                  videoUrl: videoUrl,
                  siteName: 'Instagram',
                  url: widget.url,
                  themeColor: const Color(0xFFE4405F), // Insta pink/red
                );
                _saveToCache(finalMetadata);
                return finalMetadata;
              }
            }
          }
        } catch (e) {
          debugPrint('Instagram fetch failed: $e');
        }
      }

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'TelegramBot (like TwitterBot) Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Simple content type check
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.toLowerCase().contains('text/html')) {
          return null; // Not HTML
        }

        final document = parser.parse(response.body);
        final metadata = _extractMetadata(document, uri);

        // Only cache if we found at least a title or image
        if (metadata != null) {
          _saveToCache(metadata);
        }
        return metadata;
      }
    } catch (e) {
      debugPrint('Error fetching metadata for ${widget.url}: $e');
    }

    return null;
  }

  void _saveToCache(LinkMetadata metadata) {
    _cache[widget.url] = metadata;
    AppSettings.store.setString(
      'url_preview_cache_${widget.url}',
      jsonEncode(metadata.toJson()),
    );
  }

  LinkMetadata? _extractMetadata(dom.Document document, Uri baseUrl) {
    String? title;
    String? description;
    String? imageUrl;
    String? videoUrl;
    String? siteName;
    Color? themeColor;

    // Helper to get meta content
    String? getMetaContent(String property) {
      final meta =
          document.querySelector('meta[property="$property"]') ??
          document.querySelector('meta[name="$property"]');
      return meta?.attributes['content'];
    }

    title =
        getMetaContent('og:title') ??
        getMetaContent('twitter:title') ??
        document.querySelector('title')?.text;

    description =
        getMetaContent('og:description') ??
        getMetaContent('twitter:description') ??
        getMetaContent('description');

    videoUrl =
        getMetaContent('og:video') ??
        getMetaContent('og:video:url') ??
        getMetaContent('og:video:secure_url');

    imageUrl =
        getMetaContent('og:image') ??
        getMetaContent('twitter:image') ??
        getMetaContent('twitter:image:src');

    siteName = getMetaContent('og:site_name') ?? getMetaContent('twitter:site');

    final themeColorHex = getMetaContent('theme-color');
    if (themeColorHex != null) {
      try {
        themeColor = Color(
          int.parse(themeColorHex.replaceAll('#', 'FF'), radix: 16),
        );
      } catch (_) {}
    }

    if (title == null && description == null && imageUrl == null) {
      return null;
    }

    return LinkMetadata(
      title: title,
      description: description,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      siteName: siteName,
      themeColor: themeColor,
      url: baseUrl.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkMetadata?>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final metadata = snapshot.data!;
        final theme = Theme.of(context);

        // Discord-style left border color
        final borderColor = metadata.themeColor ?? theme.colorScheme.primary;

        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              width: 400, // Max width constraint
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border(
                  left: BorderSide(color: borderColor, width: 4.0),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metadata.siteName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(
                        metadata.siteName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (metadata.title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Text(
                        metadata.title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: widget.textColor ?? theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (metadata.description != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Text(
                        metadata.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (metadata.imageUrl != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return _isPlaying && _chewieController != null
                            ? SizedBox(
                                height: 200,
                                child: Chewie(controller: _chewieController!),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    metadata.imageUrl!,
                                    width: double.infinity,
                                    height: 200, // Fixed height for hero image
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox.shrink(),
                                  ),
                                  if (metadata.videoUrl != null)
                                    _isInitializing
                                        ? const CircularProgressIndicator()
                                        : IconButton(
                                            onPressed: () =>
                                                _playVideo(metadata.videoUrl!),
                                            icon: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.5,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              child: const Icon(
                                                Icons.play_arrow,
                                                size: 48,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  if (_error != null)
                                    Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _playVideo(String url) async {
    // Dispose old controllers if they exist
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();

    setState(() {
      _isInitializing = true;
      _isPlaying = false;
      _error = null;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
        },
      );
      await _videoPlayerController!.initialize();

      // Add completion listener
      _videoPlayerController!.addListener(() {
        if (mounted &&
            _videoPlayerController!.value.isInitialized &&
            _videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration &&
            _isPlaying) {
          _videoPlayerController!.pause();
          setState(() {
            _isPlaying = false;
          });
          // Clean up controllers as they are no longer needed
          _chewieController?.dispose();
          _chewieController = null;
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
        }
      });

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = 'Failed to load video';
        });
      }
      debugPrint('Error playing video: $e');
    }
  }
}

class LinkMetadata {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? videoUrl;
  final String? siteName;
  final Color? themeColor;
  final String url;

  LinkMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.videoUrl,
    this.siteName,
    this.themeColor,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'siteName': siteName,
      'themeColor': themeColor?.value,
      'url': url,
    };
  }

  factory LinkMetadata.fromJson(Map<String, dynamic> json) {
    return LinkMetadata(
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
      siteName: json['siteName'],
      themeColor: json['themeColor'] != null ? Color(json['themeColor']) : null,
      url: json['url'] ?? '',
    );
  }
}
