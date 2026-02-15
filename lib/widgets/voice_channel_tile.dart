import 'package:flutter/material.dart';

import 'package:fluffychat/utils/voice/voice_channel_model.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/voice_participant_tile.dart';

/// A tile in the sidebar showing a voice channel.
///
/// Displays the channel name, participant count, and small participant
/// list when expanded. Tapping joins the channel.
class VoiceChannelTile extends StatelessWidget {
  final VoiceChannel channel;

  const VoiceChannelTile({required this.channel, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = Matrix.of(context);
    final voiceController = matrix.voiceChannelController;

    return AnimatedBuilder(
      animation: voiceController!,
      builder: (context, _) {
        final isActive = voiceController.activeChannelId == channel.id;
        final participants = voiceController.remoteParticipants;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel row
            InkWell(
              onTap: () {
                if (isActive) return; // Already in this channel
                voiceController.join(channel.id, channel.name, channel.roomId);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.volume_up : Icons.volume_up_outlined,
                      size: 20,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channel.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Participant count
                    if (isActive && voiceController.participantCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${voiceController.participantCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Show participants when connected to this channel
            if (isActive && participants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Column(
                  children: participants
                      .map((p) => VoiceParticipantTile.fromRemoteParticipant(p))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}
