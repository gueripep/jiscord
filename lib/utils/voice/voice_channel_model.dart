import 'package:matrix/matrix.dart';

/// Represents a voice channel defined as a Matrix room state event.
///
/// Event type: `com.jiscord.voice_channel`
/// State key: unique channel ID (e.g. "general-voice")
class VoiceChannel {
  /// Unique ID for this channel (the Matrix state_key)
  final String id;

  /// Human-readable channel name
  final String name;

  /// Maximum allowed participants (0 = unlimited)
  final int maxParticipants;

  /// Whether the channel is active
  final bool enabled;

  /// The Matrix room this channel belongs to
  final String roomId;

  const VoiceChannel({
    required this.id,
    required this.name,
    required this.roomId,
    this.maxParticipants = 0,
    this.enabled = true,
  });

  /// Parse a VoiceChannel from a Matrix state event.
  factory VoiceChannel.fromStateEvent(
    String stateKey,
    Map<String, dynamic> content,
    String roomId,
  ) {
    return VoiceChannel(
      id: stateKey,
      name: content['name'] as String? ?? 'Voice Channel',
      roomId: roomId,
      maxParticipants: content['max_participants'] as int? ?? 0,
      enabled: content['enabled'] as bool? ?? true,
    );
  }

  /// Convert to a content map for sending as a Matrix state event.
  Map<String, dynamic> toContent() => {
    'name': name,
    'max_participants': maxParticipants,
    'enabled': enabled,
  };

  /// The Matrix event type for voice channel state events.
  static const String eventType = 'com.jiscord.voice_channel';

  /// Extract all voice channels from a Matrix room's state.
  static List<VoiceChannel> fromRoom(Room room) {
    final stateMap = room.states[eventType];
    if (stateMap == null) return [];

    return stateMap.entries
        .where((entry) => entry.value.content['enabled'] == true)
        .map(
          (entry) => VoiceChannel.fromStateEvent(
            entry.key,
            entry.value.content,
            room.id,
          ),
        )
        .toList();
  }
}

/// A participant currently in a voice channel.
class VoiceParticipant {
  final String userId;
  final String displayName;
  final String joinedAt;

  const VoiceParticipant({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
  });

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    return VoiceParticipant(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}
