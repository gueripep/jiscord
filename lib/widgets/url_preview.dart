import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';

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

      // Special handling for fxtwitter/vxtwitter/fixupx API
      if (uri.host.contains('fxtwitter.com') ||
          uri.host.contains('vxtwitter.com') ||
          uri.host.contains('fixupx.com')) {
        try {
          // Manual URI construction to avoid Uri.https edge cases
          final host = uri.host.replaceAll("www.", "");
          final path = uri.path
              .replaceAll('/i/', '/')
              .replaceAll('/i/status/', '/status/');
          // Ensure we don't have double slashes or missing status

          final apiUri = Uri.https('api.$host', path);

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

              if (tweet['media'] != null) {
                final media = tweet['media'];
                if (media['videos'] != null &&
                    (media['videos'] as List).isNotEmpty) {
                  startImage = media['videos'][0]['thumbnail_url'];
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
                siteName: 'FxTwitter', // Or dynamic based on host
                url: widget.url,
                themeColor: const Color(0xFF1DA1F2), // Twitter Blue
              );
              _cache[widget.url] = metadata;
              return metadata;
            }
          }
        } catch (e) {
          debugPrint('FixTweet API failed, falling back to scraping: $e');
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
          _cache[widget.url] = metadata;
        }
        return metadata;
      }
    } catch (e) {
      debugPrint('Error fetching metadata for ${widget.url}: $e');
    }

    return null;
  }

  LinkMetadata? _extractMetadata(dom.Document document, Uri baseUrl) {
    String? title;
    String? description;
    String? imageUrl;
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

    imageUrl =
        getMetaContent('og:image') ??
        getMetaContent('twitter:image') ??
        getMetaContent('twitter:image:src') ??
        getMetaContent('og:video') ??
        getMetaContent('og:video:secure_url') ??
        getMetaContent('og:video:url');

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
                        return Image.network(
                          metadata.imageUrl!,
                          width: double.infinity,
                          height: 200, // Fixed height for hero image
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
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
}

class LinkMetadata {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final Color? themeColor;
  final String url;

  LinkMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.themeColor,
    required this.url,
  });
}
