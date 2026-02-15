import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat/swipe_notifications.dart';
import 'package:fluffychat/widgets/matrix.dart';

class SwipeableChatLayout extends StatefulWidget {
  final String roomId;
  final Widget chatPage;
  final String? spaceId;

  const SwipeableChatLayout({
    super.key,
    required this.roomId,
    required this.chatPage,
    this.spaceId,
  });

  @override
  State<SwipeableChatLayout> createState() => _SwipeableChatLayoutState();
}

class _SwipeableChatLayoutState extends State<SwipeableChatLayout> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // If we have a roomId, we start on the chat page (1).
    // If no roomId, we start on the chat list (0).
    _pageController = PageController(
      initialPage: widget.roomId.isEmpty ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SwipeableChatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If we have a roomId (active room)
    if (widget.roomId.isNotEmpty) {
      // If the room changed OR if we just tapped the already active room while on the list page
      if (oldWidget.roomId != widget.roomId ||
          (_pageController.hasClients && _pageController.page?.round() == 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && (_pageController.page ?? 0) < 0.5) {
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
    // If the room was cleared externally (e.g. by switching spaces), slide back to list
    else if (widget.roomId.isEmpty && oldWidget.roomId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && (_pageController.page ?? 0) > 0.5) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final room = widget.roomId.isEmpty
        ? null
        : client.getRoomById(widget.roomId);

    // Find if this room belongs to a space to show the correct room list if not explicitly provided
    var spaceId = widget.spaceId;
    if (spaceId == null && room != null) {
      final parents = room.spaceParents;
      if (parents.isNotEmpty) {
        spaceId = parents.first.roomId;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentPage = _pageController.hasClients
            ? _pageController.page?.round()
            : null;

        if (currentPage == 1) {
          // DISCORD STYLE: Just slide back to the list.
          // Keep the group "open" in the background and in the URL.
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          // If we are already at the list, we can allow the app to go back (e.g. to home)
          context.pop();
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: NotificationListener<SwipeBackNotification>(
          onNotification: (notification) {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            return true;
          },
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              ChatList(
                key: ValueKey('swipeable_chat_list_${spaceId ?? 'all'}'),
                activeChat: widget.roomId.isEmpty ? null : widget.roomId,
                activeSpace: spaceId,
                displayNavigationRail: true,
              ),
              widget.chatPage,
            ],
          ),
        ),
      ),
    );
  }
}
