import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart' as sdk;
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/unread_bubble.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/utils/string_color.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/public_room_dialog.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/utils/voice/voice_channel_model.dart';
import 'package:fluffychat/widgets/voice_channel_tile.dart';
import 'package:fluffychat/pages/voice_channel/voice_channel_dialog.dart';
import 'package:fluffychat/utils/voice/voice_channel_manager.dart';

enum SpaceChildAction { edit, moveToSpace, removeFromSpace }

enum SpaceActions { settings, invite, members, leave }

class SpaceView extends StatefulWidget {
  final String spaceId;
  final void Function() onBack;
  final void Function(Room room) onChatTab;
  final String? activeChat;

  const SpaceView({
    required this.spaceId,
    required this.onBack,
    required this.onChatTab,
    required this.activeChat,
    super.key,
  });

  @override
  State<SpaceView> createState() => _SpaceViewState();
}

class _SpaceViewState extends State<SpaceView> {
  final List<SpaceRoomsChunk$2> _discoveredChildren = [];
  String? _nextBatch;
  bool _noMoreRooms = false;
  bool _isLoading = false;

  @override
  void initState() {
    _loadHierarchy();
    super.initState();
  }

  void _loadHierarchy() async {
    final matrix = Matrix.of(context);
    final room = matrix.client.getRoomById(widget.spaceId);
    if (room == null) return;

    final cacheKey = 'spaces_history_cache${room.id}';
    if (_discoveredChildren.isEmpty) {
      final cachedChildren = matrix.store.getStringList(cacheKey);
      if (cachedChildren != null) {
        try {
          _discoveredChildren.addAll(
            cachedChildren.map(
              (jsonString) =>
                  SpaceRoomsChunk$2.fromJson(jsonDecode(jsonString)),
            ),
          );
        } catch (e, s) {
          Logs().e('Unable to json decode spaces hierarchy cache!', e, s);
          matrix.store.remove(cacheKey);
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hierarchy = await room.client.getSpaceHierarchy(
        widget.spaceId,
        suggestedOnly: false,
        maxDepth: 2,
        from: _nextBatch,
      );
      if (!mounted) return;
      setState(() {
        if (_nextBatch == null) _discoveredChildren.clear();
        _nextBatch = hierarchy.nextBatch;
        if (hierarchy.nextBatch == null) {
          _noMoreRooms = true;
        }
        _discoveredChildren.addAll(
          hierarchy.rooms.where((room) => room.roomId != widget.spaceId),
        );
        _isLoading = false;
      });

      if (_nextBatch == null) {
        matrix.store.setStringList(
          cacheKey,
          _discoveredChildren
              .map((child) => jsonEncode(child.toJson()))
              .toList(),
        );
      }
    } catch (e, s) {
      Logs().w('Unable to load hierarchy', e, s);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _joinChildRoom(SpaceRoomsChunk$2 item) async {
    final client = Matrix.of(context).client;
    final space = client.getRoomById(widget.spaceId);

    final joined = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => PublicRoomDialog(
        chunk: item,
        via: space?.spaceChildren
            .firstWhereOrNull((child) => child.roomId == item.roomId)
            ?.via,
      ),
    );
    if (mounted && joined == true) {
      setState(() {});
    }
  }

  void _onSpaceAction(SpaceActions action) async {
    final space = Matrix.of(context).client.getRoomById(widget.spaceId);

    switch (action) {
      case SpaceActions.settings:
        await space?.postLoad();
        context.push('/rooms/${widget.spaceId}/details');
        break;
      case SpaceActions.invite:
        await space?.postLoad();
        context.push('/rooms/${widget.spaceId}/invite');
        break;
      case SpaceActions.members:
        await space?.postLoad();
        context.push('/rooms/${widget.spaceId}/details/members');
        break;
      case SpaceActions.leave:
        final confirmed = await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).areYouSure,
          message: L10n.of(context).archiveRoomDescription,
          okLabel: L10n.of(context).leave,
          cancelLabel: L10n.of(context).cancel,
          isDestructive: true,
        );
        if (!mounted) return;
        if (confirmed != OkCancelResult.ok) return;

        final success = await showFutureLoadingDialog(
          context: context,
          future: () async => await space?.leave(),
        );
        if (!mounted) return;
        if (success.error != null) return;
        widget.onBack();
    }
  }

  void _addChat() async {
    final names = await showTextInputDialog(
      context: context,
      title: L10n.of(context).createGroup,
      hintText: L10n.of(context).groupName,
      minLines: 1,
      maxLines: 1,
      maxLength: 64,
      validator: (text) {
        if (text.isEmpty) {
          return L10n.of(context).pleaseChoose;
        }
        return null;
      },
      okLabel: L10n.of(context).create,
      cancelLabel: L10n.of(context).cancel,
    );
    if (names == null) return;
    final client = Matrix.of(context).client;
    final result = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final activeSpace = client.getRoomById(widget.spaceId)!;
        await activeSpace.postLoad();
        final isPublicSpace = activeSpace.joinRules == JoinRules.public;

        final roomId = await client.createGroupChat(
          enableEncryption: !isPublicSpace,
          groupName: names,
          preset: isPublicSpace
              ? CreateRoomPreset.publicChat
              : CreateRoomPreset.privateChat,
          visibility: isPublicSpace
              ? sdk.Visibility.public
              : sdk.Visibility.private,
          initialState: isPublicSpace
              ? null
              : [
                  StateEvent(
                    content: {
                      'join_rule': 'restricted',
                      'allow': [
                        {
                          'room_id': widget.spaceId,
                          'type': 'm.room_membership',
                        },
                      ],
                    },
                    type: EventTypes.RoomJoinRules,
                  ),
                ],
        );
        await activeSpace.setSpaceChild(roomId);
      },
    );
    if (result.error != null) return;
    setState(() {
      _nextBatch = null;
      _discoveredChildren.clear();
    });
    _loadHierarchy();
  }

  void _showSpaceChildEditMenu(BuildContext posContext, String roomId) async {
    final overlay =
        Overlay.of(posContext).context.findRenderObject() as RenderBox;

    final button = posContext.findRenderObject() as RenderBox;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, -65), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + const Offset(-50, 0),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<SpaceChildAction>(
      context: posContext,
      position: position,
      items: [
        PopupMenuItem(
          value: SpaceChildAction.moveToSpace,
          child: Row(
            mainAxisSize: .min,
            children: [
              const Icon(Icons.move_down_outlined),
              const SizedBox(width: 12),
              Text(L10n.of(context).moveToDifferentSpace),
            ],
          ),
        ),
        PopupMenuItem(
          value: SpaceChildAction.edit,
          child: Row(
            mainAxisSize: .min,
            children: [
              const Icon(Icons.edit_outlined),
              const SizedBox(width: 12),
              Text(L10n.of(context).edit),
            ],
          ),
        ),
        PopupMenuItem(
          value: SpaceChildAction.removeFromSpace,
          child: Row(
            mainAxisSize: .min,
            children: [
              const Icon(Icons.group_remove_outlined),
              const SizedBox(width: 12),
              Text(L10n.of(context).removeFromSpace),
            ],
          ),
        ),
      ],
    );
    if (action == null) return;
    if (!mounted) return;
    final space = Matrix.of(context).client.getRoomById(widget.spaceId);
    if (space == null) return;
    switch (action) {
      case SpaceChildAction.edit:
        context.push('/rooms/${widget.spaceId}/details');
      case SpaceChildAction.moveToSpace:
        final spacesWithPowerLevels = space.client.rooms
            .where(
              (room) =>
                  room.isSpace &&
                  room.canChangeStateEvent(EventTypes.SpaceChild) &&
                  room.id != widget.spaceId,
            )
            .toList();
        final newSpace = await showModalActionPopup(
          context: context,
          title: L10n.of(context).space,
          actions: spacesWithPowerLevels
              .map(
                (space) => AdaptiveModalAction(
                  value: space,
                  label: space.getLocalizedDisplayname(
                    MatrixLocals(L10n.of(context)),
                  ),
                ),
              )
              .toList(),
        );
        if (newSpace == null) return;
        final result = await showFutureLoadingDialog(
          context: context,
          future: () async {
            await newSpace.setSpaceChild(newSpace.id);
            await space.removeSpaceChild(roomId);
          },
        );
        if (result.isError) return;
        if (!mounted) return;
        _nextBatch = null;
        _loadHierarchy();
        return;

      case SpaceChildAction.removeFromSpace:
        final consent = await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).removeFromSpace,
          message: L10n.of(context).removeFromSpaceDescription,
        );
        if (consent != OkCancelResult.ok) return;
        if (!mounted) return;
        final result = await showFutureLoadingDialog(
          context: context,
          future: () => space.removeSpaceChild(roomId),
        );
        if (result.isError) return;
        if (!mounted) return;
        _nextBatch = null;
        _loadHierarchy();
        return;
    }
  }

  void _showVoiceChannelMenu(VoiceChannel channel) async {
    final action = await showModalActionPopup<String>(
      context: context,
      title: channel.name,
      actions: [
        AdaptiveModalAction(value: 'edit', label: L10n.of(context).edit),
        AdaptiveModalAction(
          value: 'delete',
          label: L10n.of(context).delete,
          isDestructive: true,
        ),
      ],
    );

    if (action == null) return;
    final room = Matrix.of(context).client.getRoomById(widget.spaceId)!;

    if (action == 'edit') {
      final result = await VoiceChannelDialog.show(
        context,
        room: room,
        existingChannel: channel,
      );
      if (result == true) setState(() {});
    } else if (action == 'delete') {
      final confirmed = await showOkCancelAlertDialog(
        context: context,
        title: L10n.of(context).areYouSure,
        message: 'Are you sure you want to delete this voice channel?',
        okLabel: L10n.of(context).delete,
        isDestructive: true,
      );
      if (confirmed != OkCancelResult.ok) return;

      await showFutureLoadingDialog(
        context: context,
        future: () => VoiceChannelManager.deleteChannel(
          room: room,
          channelId: channel.id,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final room = Matrix.of(context).client.getRoomById(widget.spaceId);
    final displayname =
        room?.getLocalizedDisplayname() ?? L10n.of(context).nothingFound;
    const avatarSize = Avatar.defaultSize / 1.5;
    final isAdmin = room?.canChangeStateEvent(EventTypes.SpaceChild) == true;
    return Scaffold(
      appBar: AppBar(
        leading: null,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: ListTile(
          contentPadding: const EdgeInsets.only(left: 16.0),
          leading: Avatar(
            size: avatarSize,
            mxContent: room?.avatar,
            name: displayname,
            border: BorderSide(width: 1, color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
          title: Text(
            displayname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          PopupMenuButton<SpaceActions>(
            useRootNavigator: true,
            onSelected: _onSpaceAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SpaceActions.settings,
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.settings_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).settings),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SpaceActions.invite,
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.person_add_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).invite),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SpaceActions.members,
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.group_outlined),
                    const SizedBox(width: 12),
                    Text(
                      L10n.of(context).countParticipants(
                        room?.summary.mJoinedMemberCount ?? 1,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SpaceActions.leave,
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.delete_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).leave),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: room == null
          ? const Center(child: Icon(Icons.search_outlined, size: 80))
          : StreamBuilder(
              stream: room.client.onSync.stream
                  .where((s) => s.hasRoomUpdate)
                  .rateLimit(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'TEXT CHANNELS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isAdmin)
                              InkWell(
                                onTap: _addChat,
                                borderRadius: BorderRadius.circular(12),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: _discoveredChildren.length + 1,
                      itemBuilder: (context, i) {
                        if (i == _discoveredChildren.length) {
                          if (_noMoreRooms || _isLoading) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 2.0,
                            ),
                            child: TextButton(
                              onPressed: _isLoading ? null : _loadHierarchy,
                              child: _isLoading
                                  ? const CircularProgressIndicator.adaptive()
                                  : Text(L10n.of(context).loadMore),
                            ),
                          );
                        }
                        final item = _discoveredChildren[i];
                        final displayname =
                            item.name ??
                            item.canonicalAlias ??
                            L10n.of(context).emptyChat;
                        var joinedRoom = room.client.getRoomById(item.roomId);
                        if (joinedRoom?.membership == Membership.leave) {
                          joinedRoom = null;
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(
                              AppConfig.borderRadius,
                            ),
                            clipBehavior: Clip.hardEdge,
                            color:
                                joinedRoom != null &&
                                    widget.activeChat == joinedRoom.id
                                ? theme.colorScheme.secondaryContainer
                                : Colors.transparent,
                            child: HoverBuilder(
                              builder: (context, hovered) => GestureDetector(
                                onSecondaryTap: isAdmin
                                    ? () => _showSpaceChildEditMenu(
                                        context,
                                        item.roomId,
                                      )
                                    : null,
                                child: ListTile(
                                  visualDensity: const VisualDensity(
                                    vertical: -0.5,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  onTap: joinedRoom != null
                                      ? () => widget.onChatTab(joinedRoom!)
                                      : () => _joinChildRoom(item),
                                  onLongPress: isAdmin
                                      ? () => _showSpaceChildEditMenu(
                                          context,
                                          item.roomId,
                                        )
                                      : null,
                                  leading: hovered && isAdmin
                                      ? SizedBox.square(
                                          dimension: avatarSize,
                                          child: IconButton(
                                            splashRadius: avatarSize,
                                            iconSize: 14,
                                            style: IconButton.styleFrom(
                                              foregroundColor: theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .tertiaryContainer,
                                            ),
                                            onPressed: () =>
                                                _showSpaceChildEditMenu(
                                                  context,
                                                  item.roomId,
                                                ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        )
                                      : Avatar(
                                          size: avatarSize,
                                          mxContent: item.avatarUrl,
                                          name: '#',
                                          backgroundColor: theme
                                              .colorScheme
                                              .surfaceContainer,
                                          textColor:
                                              item.name?.darkColor ??
                                              theme.colorScheme.onSurface,
                                          border: item.roomType == 'm.space'
                                              ? BorderSide(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                )
                                              : null,
                                          borderRadius:
                                              item.roomType == 'm.space'
                                              ? BorderRadius.circular(
                                                  AppConfig.borderRadius / 4,
                                                )
                                              : null,
                                        ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Opacity(
                                          opacity: joinedRoom == null ? 0.5 : 1,
                                          child: Text(
                                            displayname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (joinedRoom != null)
                                        UnreadBubble(room: joinedRoom)
                                      else
                                        const Icon(
                                          Icons.chevron_right_outlined,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: FutureBuilder<List<VoiceChannel>>(
                        future: VoiceChannel.fetchFromRoom(room),
                        builder: (context, snapshot) {
                          final voiceChannels = snapshot.data ?? [];
                          if (voiceChannels.isEmpty && !isAdmin) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'VOICE CHANNELS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isAdmin)
                                      InkWell(
                                        onTap: () async {
                                          final result =
                                              await VoiceChannelDialog.show(
                                                context,
                                                room: room,
                                              );
                                          if (result == true) {
                                            setState(() {});
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ...voiceChannels.map(
                                (ch) => VoiceChannelTile(
                                  channel: ch,
                                  onLongPress: isAdmin
                                      ? () => _showVoiceChannelMenu(ch)
                                      : null,
                                  onSecondaryTap: isAdmin
                                      ? () => _showVoiceChannelMenu(ch)
                                      : null,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(top: 32)),
                  ],
                );
              },
            ),
    );
  }
}
