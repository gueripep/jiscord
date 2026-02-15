import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/voice/voice_channel_model.dart';

/// Service for managing voice channel state events in a Matrix room.
///
/// Handles CRUD operations on `com.jiscord.voice_channel` state events.
class VoiceChannelManager {
  /// Create a new voice channel in a Matrix room.
  static Future<void> createChannel({
    required Room room,
    required String name,
    String? channelId,
    int maxParticipants = 0,
  }) async {
    final id =
        channelId ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    Logs().i('[Voice] Creating channel "$name" (id: $id) in room ${room.id}');

    final eventId = await room.client.setRoomStateWithKey(
      room.id,
      VoiceChannel.eventType,
      id,
      {'name': name, 'max_participants': maxParticipants, 'enabled': true},
    );

    Logs().i('[Voice] Channel created, eventId: $eventId');

    // Manually inject the state event into the room's local state cache
    // so it appears immediately without waiting for sync.
    room.setState(
      Event(
        type: VoiceChannel.eventType,
        stateKey: id,
        content: {
          'name': name,
          'max_participants': maxParticipants,
          'enabled': true,
        },
        eventId: eventId,
        senderId: room.client.userID!,
        originServerTs: DateTime.now(),
        room: room,
      ),
    );

    Logs().i('[Voice] Injected state event into local room cache');
  }

  /// Delete (disable) a voice channel.
  static Future<void> deleteChannel({
    required Room room,
    required String channelId,
  }) async {
    final eventId = await room.client.setRoomStateWithKey(
      room.id,
      VoiceChannel.eventType,
      channelId,
      {'enabled': false},
    );

    room.setState(
      Event(
        type: VoiceChannel.eventType,
        stateKey: channelId,
        content: {'enabled': false},
        eventId: eventId,
        senderId: room.client.userID!,
        originServerTs: DateTime.now(),
        room: room,
      ),
    );
  }

  /// Update a voice channel's settings.
  static Future<void> updateChannel({
    required Room room,
    required String channelId,
    required String name,
    int maxParticipants = 0,
  }) async {
    final content = {
      'name': name,
      'max_participants': maxParticipants,
      'enabled': true,
    };

    final eventId = await room.client.setRoomStateWithKey(
      room.id,
      VoiceChannel.eventType,
      channelId,
      content,
    );

    room.setState(
      Event(
        type: VoiceChannel.eventType,
        stateKey: channelId,
        content: content,
        eventId: eventId,
        senderId: room.client.userID!,
        originServerTs: DateTime.now(),
        room: room,
      ),
    );
  }
}
