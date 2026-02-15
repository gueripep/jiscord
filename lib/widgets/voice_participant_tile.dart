import 'package:flutter/material.dart';

import 'package:livekit_client/livekit_client.dart' as lk;

/// A tile displaying a single voice channel participant.
///
/// Shows avatar (initials), display name, and a speaking indicator.
class VoiceParticipantTile extends StatelessWidget {
  final String displayName;
  final bool isSpeaking;
  final bool isMuted;

  const VoiceParticipantTile({
    required this.displayName,
    this.isSpeaking = false,
    this.isMuted = false,
    super.key,
  });

  /// Build from a LiveKit RemoteParticipant.
  factory VoiceParticipantTile.fromRemoteParticipant(
    lk.RemoteParticipant participant,
  ) {
    final name = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    return VoiceParticipantTile(
      displayName: name,
      isSpeaking: participant.isSpeaking,
      isMuted: !participant.isMicrophoneEnabled(),
    );
  }

  String get _initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with speaking ring
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSpeaking
                  ? Border.all(color: Colors.green, width: 2)
                  : null,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Center(
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Flexible(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 13,
                color: isMuted
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Muted icon
          if (isMuted) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.mic_off,
              size: 14,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }
}
