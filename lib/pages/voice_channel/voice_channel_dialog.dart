import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/voice/voice_channel_manager.dart';
import 'package:fluffychat/utils/voice/voice_channel_model.dart';

/// Dialog for creating or editing a voice channel.
class VoiceChannelDialog extends StatefulWidget {
  final Room room;
  final VoiceChannel? existingChannel;

  const VoiceChannelDialog({
    required this.room,
    this.existingChannel,
    super.key,
  });

  /// Show the dialog and return true if a channel was created/updated.
  static Future<bool?> show(
    BuildContext context, {
    required Room room,
    VoiceChannel? existingChannel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          VoiceChannelDialog(room: room, existingChannel: existingChannel),
    );
  }

  @override
  State<VoiceChannelDialog> createState() => _VoiceChannelDialogState();
}

class _VoiceChannelDialogState extends State<VoiceChannelDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _maxParticipantsController;
  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.existingChannel != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingChannel?.name ?? '',
    );
    _maxParticipantsController = TextEditingController(
      text: widget.existingChannel?.maxParticipants.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Channel name is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final maxP = int.tryParse(_maxParticipantsController.text.trim()) ?? 0;

      if (_isEditing) {
        await VoiceChannelManager.updateChannel(
          room: widget.room,
          channelId: widget.existingChannel!.id,
          name: name,
          maxParticipants: maxP,
        );
      } else {
        await VoiceChannelManager.createChannel(
          room: widget.room,
          name: name,
          maxParticipants: maxP,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Voice Channel' : 'Create Voice Channel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Channel Name',
              hintText: 'e.g. General Voice',
              prefixIcon: const Icon(Icons.volume_up),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxParticipantsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max Participants',
              hintText: '0 = unlimited',
              prefixIcon: const Icon(Icons.people),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
