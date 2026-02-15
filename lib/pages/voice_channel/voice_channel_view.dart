import 'package:flutter/material.dart';

import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:fluffychat/utils/voice/voice_channel_controller.dart';
import 'package:fluffychat/widgets/matrix.dart';

/// Full-screen expanded view of the current voice channel.
///
/// Shows all participants with speaking indicators, video feeds when
/// cameras are on, and provides mute/deafen/camera/leave controls.
class VoiceChannelView extends StatelessWidget {
  const VoiceChannelView({super.key});

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix.of(context);
    final controller = matrix.voiceChannelController;

    if (controller == null || !controller.isConnected) {
      return const Scaffold(
        body: Center(child: Text('Not connected to a voice channel')),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildView(context, controller),
    );
  }

  Widget _buildView(BuildContext context, VoiceChannelController controller) {
    final hasAnyVideo =
        controller.isCameraOn ||
        controller.remoteParticipants.any((p) => p.isCameraEnabled());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Text(controller.activeChannelName ?? 'Voice Channel'),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Participant area — video grid or audio-only list
          Expanded(
            child: hasAnyVideo
                ? _VideoGrid(controller: controller)
                : _AudioOnlyList(controller: controller),
          ),
          // Controls bar
          _ControlsBar(controller: controller),
        ],
      ),
    );
  }
}

/// Audio-only participant list (no video tracks active).
class _AudioOnlyList extends StatelessWidget {
  final VoiceChannelController controller;

  const _AudioOnlyList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.participantCount == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_off,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No one else is here',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ParticipantCard(
          displayName: 'You',
          isSpeaking: false,
          isMuted: controller.isMuted,
          isLocal: true,
        ),
        ...controller.remoteParticipants.map(
          (p) => _ParticipantCard(
            displayName: p.name.isNotEmpty ? p.name : p.identity,
            isSpeaking: p.isSpeaking,
            isMuted: !p.isMicrophoneEnabled(),
            isLocal: false,
          ),
        ),
      ],
    );
  }
}

/// Video grid layout — shows video tiles for participants with cameras on,
/// and small audio-only indicators for those without.
class _VideoGrid extends StatelessWidget {
  final VoiceChannelController controller;

  const _VideoGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    // Local participant tile
    if (controller.isCameraOn && controller.localVideoTrack != null) {
      tiles.add(
        _VideoTile(
          displayName: 'You',
          isSpeaking: false,
          isMuted: controller.isMuted,
          isLocal: true,
          videoTrack: controller.localVideoTrack!,
        ),
      );
    } else {
      tiles.add(
        _ParticipantCard(
          displayName: 'You',
          isSpeaking: false,
          isMuted: controller.isMuted,
          isLocal: true,
        ),
      );
    }

    // Remote participant tiles
    for (final participant in controller.remoteParticipants) {
      final videoTrack = _getRemoteVideoTrack(participant);
      final name = participant.name.isNotEmpty
          ? participant.name
          : participant.identity;

      if (videoTrack != null) {
        tiles.add(
          _VideoTile(
            displayName: name,
            isSpeaking: participant.isSpeaking,
            isMuted: !participant.isMicrophoneEnabled(),
            isLocal: false,
            videoTrack: videoTrack,
          ),
        );
      } else {
        tiles.add(
          _ParticipantCard(
            displayName: name,
            isSpeaking: participant.isSpeaking,
            isMuted: !participant.isMicrophoneEnabled(),
            isLocal: false,
          ),
        );
      }
    }

    // Adaptive grid: 1 col for 1-2, 2 cols for 3+
    final crossAxisCount = tiles.length <= 2 ? 1 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: crossAxisCount == 1 ? 16 / 9 : 4 / 3,
      children: tiles,
    );
  }

  lk.VideoTrack? _getRemoteVideoTrack(lk.RemoteParticipant participant) {
    for (final pub in participant.videoTrackPublications) {
      if (pub.subscribed && pub.track is lk.VideoTrack) {
        return pub.track as lk.VideoTrack;
      }
    }
    return null;
  }
}

/// A single video tile showing a participant's camera feed.
class _VideoTile extends StatelessWidget {
  final String displayName;
  final bool isSpeaking;
  final bool isMuted;
  final bool isLocal;
  final lk.VideoTrack videoTrack;

  const _VideoTile({
    required this.displayName,
    required this.isSpeaking,
    required this.isMuted,
    required this.isLocal,
    required this.videoTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSpeaking
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video feed
          lk.VideoTrackRenderer(videoTrack),
          // Name overlay
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMuted) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.mic_off, size: 14, color: Colors.red),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio-only participant card (no camera).
class _ParticipantCard extends StatelessWidget {
  final String displayName;
  final bool isSpeaking;
  final bool isMuted;
  final bool isLocal;

  const _ParticipantCard({
    required this.displayName,
    required this.isSpeaking,
    required this.isMuted,
    required this.isLocal,
  });

  String get _initials {
    if (isLocal) return 'ME';
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSpeaking
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLocal
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLocal
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isLocal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isMuted)
              Icon(
                Icons.mic_off,
                size: 18,
                color: theme.colorScheme.error.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}

/// Controls bar at the bottom of the expanded voice view.
class _ControlsBar extends StatelessWidget {
  final VoiceChannelController controller;

  const _ControlsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LargeControlButton(
              icon: controller.isMuted ? Icons.mic_off : Icons.mic,
              label: controller.isMuted ? 'Unmute' : 'Mute',
              isActive: controller.isMuted,
              onPressed: controller.toggleMute,
            ),
            const SizedBox(width: 24),
            _LargeControlButton(
              icon: controller.isDeafened ? Icons.headset_off : Icons.headset,
              label: controller.isDeafened ? 'Undeafen' : 'Deafen',
              isActive: controller.isDeafened,
              onPressed: controller.toggleDeafen,
            ),
            const SizedBox(width: 24),
            _LargeControlButton(
              icon: controller.isCameraOn ? Icons.videocam : Icons.videocam_off,
              label: controller.isCameraOn ? 'Camera Off' : 'Camera',
              isActive: controller.isCameraOn,
              activeColor: theme.colorScheme.primary,
              onPressed: controller.toggleCamera,
            ),
            const SizedBox(width: 24),
            _LargeControlButton(
              icon: Icons.call_end,
              label: 'Leave',
              isActive: true,
              activeColor: Colors.red,
              onPressed: () {
                controller.leave();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onPressed;

  const _LargeControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? (activeColor ?? theme.colorScheme.error)
        : theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
