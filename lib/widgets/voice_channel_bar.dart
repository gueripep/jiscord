import 'package:flutter/material.dart';

import 'package:fluffychat/utils/voice/voice_channel_controller.dart';
import 'package:fluffychat/widgets/matrix.dart';

/// Persistent bottom bar that appears when the user is in a voice channel.
///
/// Shows channel name, participant count, and mute/deafen/leave controls.
/// Persists across all screens in the app.
class VoiceChannelBar extends StatelessWidget {
  const VoiceChannelBar({super.key});

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix.of(context);
    final controller = matrix.voiceChannelController;

    if (controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isConnected && !controller.isConnecting) {
          return const SizedBox.shrink();
        }

        return _buildBar(context, controller);
      },
    );
  }

  Widget _buildBar(BuildContext context, VoiceChannelController controller) {
    final theme = Theme.of(context);

    return Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Connection indicator
              if (controller.isConnecting) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ] else ...[
                // Voice icon
                Icon(Icons.volume_up, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                // Channel info
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.activeChannelName ?? 'Voice Channel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '${controller.participantCount} participant${controller.participantCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Controls
                _ControlButton(
                  icon: controller.isMuted ? Icons.mic_off : Icons.mic,
                  isActive: controller.isMuted,
                  onPressed: controller.toggleMute,
                  tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                ),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: controller.isDeafened
                      ? Icons.headset_off
                      : Icons.headset,
                  isActive: controller.isDeafened,
                  onPressed: controller.toggleDeafen,
                  tooltip: controller.isDeafened ? 'Undeafen' : 'Deafen',
                ),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: controller.isCameraOn
                      ? Icons.videocam
                      : Icons.videocam_off,
                  isActive: controller.isCameraOn,
                  activeColor: theme.colorScheme.primary,
                  onPressed: controller.toggleCamera,
                  tooltip: controller.isCameraOn
                      ? 'Turn Off Camera'
                      : 'Turn On Camera',
                ),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: Icons.call_end,
                  isActive: true,
                  activeColor: Colors.red,
                  onPressed: controller.leave,
                  tooltip: 'Leave',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onPressed;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    this.activeColor,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? (activeColor ?? theme.colorScheme.error)
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
