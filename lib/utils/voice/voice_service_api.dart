import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'voice_channel_model.dart';

/// HTTP client for the Jiscord Voice Service backend.
///
/// Handles token requests and participant list fetching.
class VoiceServiceApi {
  final String baseUrl;
  final Client matrixClient;

  VoiceServiceApi({required this.baseUrl, required this.matrixClient});

  /// Get Matrix access token for authentication.
  String? get _accessToken => matrixClient.accessToken;

  /// Request a LiveKit token for joining a voice channel.
  ///
  /// Returns a map with `token` (LiveKit JWT) and `livekitUrl`.
  Future<Map<String, String>> requestToken({
    required String channelId,
    String? displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode({
        'channelId': channelId,
        'displayName': displayName ?? matrixClient.userID,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get voice token: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'token': data['token'] as String,
      'livekitUrl': data['livekitUrl'] as String,
    };
  }

  /// Fetch the current participant list for a voice channel.
  Future<List<VoiceParticipant>> getParticipants(String channelId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/participants/$channelId'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get participants: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['participants'] as List<dynamic>? ?? [];

    return list
        .map((p) => VoiceParticipant.fromJson(p as Map<String, dynamic>))
        .toList();
  }
}
