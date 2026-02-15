import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:matrix/matrix.dart';

import 'voice_service_api.dart';

/// Manages the active voice channel session.
///
/// Handles connecting/disconnecting from LiveKit rooms,
/// muting/deafening, and exposing participant state.
class VoiceChannelController extends ChangeNotifier {
  final VoiceServiceApi _api;
  final Client _matrixClient;

  VoiceChannelController({
    required VoiceServiceApi api,
    required Client matrixClient,
  }) : _api = api,
       _matrixClient = matrixClient;

  // --- State ---

  lk.Room? _room;
  lk.LocalParticipant? _localParticipant;
  String? _activeChannelId;
  String? _activeChannelName;
  String? _activeRoomId;
  bool _isMuted = false;
  bool _isDeafened = false;
  bool _isConnecting = false;
  bool _isCameraOn = false;

  /// Whether the user is currently in a voice channel.
  bool get isConnected => _room != null && _activeChannelId != null;

  /// Whether a connection attempt is in progress.
  bool get isConnecting => _isConnecting;

  /// The active voice channel ID (null if not connected).
  String? get activeChannelId => _activeChannelId;

  /// The active voice channel display name.
  String? get activeChannelName => _activeChannelName;

  /// The Matrix room ID that owns the active channel.
  String? get activeRoomId => _activeRoomId;

  /// Whether the local user is muted.
  bool get isMuted => _isMuted;

  /// Whether the local user is deafened.
  bool get isDeafened => _isDeafened;

  /// Whether the local user's camera is on.
  bool get isCameraOn => _isCameraOn;

  /// All remote participants in the current voice channel.
  List<lk.RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];

  /// Total participant count including local user.
  int get participantCount => isConnected ? remoteParticipants.length + 1 : 0;

  /// Get the local video track (if camera is on).
  lk.LocalVideoTrack? get localVideoTrack {
    if (_localParticipant == null) return null;
    for (final pub in _localParticipant!.videoTrackPublications) {
      if (pub.track is lk.LocalVideoTrack) {
        return pub.track as lk.LocalVideoTrack;
      }
    }
    return null;
  }

  /// Get the local participant reference.
  lk.LocalParticipant? get localParticipant => _localParticipant;

  /// Get the LiveKit room reference.
  lk.Room? get room => _room;

  // --- Actions ---

  /// Join a voice channel.
  ///
  /// Fetches a LiveKit token from the voice service, connects to the
  /// LiveKit room, and publishes the local audio track.
  Future<void> join(String channelId, String channelName, String roomId) async {
    if (_isConnecting) return;
    if (_activeChannelId == channelId) return;

    // Leave current channel first if in one
    if (isConnected) {
      await leave();
    }

    _isConnecting = true;
    notifyListeners();

    try {
      // Get display name from Matrix profile
      final displayName = _matrixClient.userID != null
          ? (await _matrixClient.getProfileFromUserId(
                  _matrixClient.userID!,
                )).displayName ??
                _matrixClient.userID!
          : 'Unknown';

      // Request token from voice service
      final tokenData = await _api.requestToken(
        channelId: channelId,
        displayName: displayName,
      );

      // Connect to LiveKit room
      final room = lk.Room();

      // Listen for participant events
      room.addListener(_onRoomUpdate);

      await room.connect(
        tokenData['livekitUrl']!,
        tokenData['token']!,
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: lk.AudioPublishOptions(
            dtx:
                true, // Discontinuous transmission (saves bandwidth when silent)
          ),
        ),
      );

      // Enable microphone
      await room.localParticipant?.setMicrophoneEnabled(true);

      _room = room;
      _localParticipant = room.localParticipant;
      _activeChannelId = channelId;
      _activeChannelName = channelName;
      _activeRoomId = roomId;
      _isMuted = false;
      _isDeafened = false;
      _isCameraOn = false;

      Logs().i('[Voice] Joined channel: $channelName ($channelId)');
    } catch (e, s) {
      Logs().e('[Voice] Failed to join channel', e, s);
      // Clean up on failure
      _room?.removeListener(_onRoomUpdate);
      await _room?.disconnect();
      _room = null;
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Leave the current voice channel.
  Future<void> leave() async {
    if (!isConnected) return;

    final channelName = _activeChannelName;

    _room?.removeListener(_onRoomUpdate);
    await _room?.disconnect();

    _room = null;
    _localParticipant = null;
    _activeChannelId = null;
    _activeChannelName = null;
    _activeRoomId = null;
    _isMuted = false;
    _isDeafened = false;
    _isCameraOn = false;

    Logs().i('[Voice] Left channel: $channelName');
    notifyListeners();
  }

  /// Toggle microphone mute.
  Future<void> toggleMute() async {
    if (!isConnected || _localParticipant == null) return;

    _isMuted = !_isMuted;
    await _localParticipant!.setMicrophoneEnabled(!_isMuted);
    notifyListeners();
  }

  /// Toggle deafen (mute all incoming audio).
  Future<void> toggleDeafen() async {
    if (!isConnected || _room == null) return;

    _isDeafened = !_isDeafened;

    // When deafened, also mute outgoing audio
    if (_isDeafened && !_isMuted) {
      _isMuted = true;
      await _localParticipant?.setMicrophoneEnabled(false);
    }

    // Mute/unmute all incoming audio tracks
    for (final participant in _room!.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        if (_isDeafened) {
          publication.disable();
        } else {
          publication.enable();
        }
      }
    }

    // When un-deafening, also un-mute outgoing audio
    if (!_isDeafened) {
      _isMuted = false;
      await _localParticipant?.setMicrophoneEnabled(true);
    }

    notifyListeners();
  }

  /// Toggle camera on/off.
  Future<void> toggleCamera() async {
    if (!isConnected || _localParticipant == null) return;

    _isCameraOn = !_isCameraOn;
    await _localParticipant!.setCameraEnabled(_isCameraOn);
    notifyListeners();
  }

  // --- Internal ---

  /// Called when the LiveKit room state changes.
  void _onRoomUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }
}
