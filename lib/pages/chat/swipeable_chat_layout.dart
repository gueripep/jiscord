import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat/swipe_notifications.dart';
import 'package:fluffychat/widgets/matrix.dart';

/// Custom scroll physics for snappier page transitions.
///
/// Uses a higher minimum velocity threshold (700 px/s) so that only
/// intentional swipes trigger page changes, preventing accidental ones.
class _SnappyPageScrollPhysics extends ScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 80, stiffness: 100, damping: 1);
}

class SwipeableChatLayoutTransition extends InheritedWidget {
  final ValueNotifier<bool> isTransitioning;

  const SwipeableChatLayoutTransition({
    super.key,
    required this.isTransitioning,
    required super.child,
  });

  static SwipeableChatLayoutTransition? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SwipeableChatLayoutTransition>();
  }

  @override
  bool updateShouldNotify(SwipeableChatLayoutTransition oldWidget) {
    return isTransitioning != oldWidget.isTransitioning;
  }
}

/// Wrapper that keeps its child alive in the PageView when scrolled off-screen.
/// This is the "View Portaling" technique — prevents the white flash and
/// full re-render that occurs when swiping back to an already-visited page.
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Animation constants matching Material Design 3 recommended values.
const _kAnimationDuration = Duration(milliseconds: 250);

/// Material 3 standard deceleration curve — snappier than plain easeOut.
const _kAnimationCurve = Curves.easeOutCubic;

class SwipeableChatLayout extends StatefulWidget {
  static final GlobalKey<SwipeableChatLayoutState> globalKey = GlobalKey();

  final String roomId;
  final Widget chatPage;
  final String? spaceId;
  final bool openInBackground;

  SwipeableChatLayout({
    required this.roomId,
    required this.chatPage,
    this.spaceId,
    this.openInBackground = false,
  }) : super(key: globalKey);

  @override
  State<SwipeableChatLayout> createState() => SwipeableChatLayoutState();
}

class SwipeableChatLayoutState extends State<SwipeableChatLayout> {
  late final PageController _pageController;
  final ValueNotifier<bool> _isTransitioning = ValueNotifier(false);

  void _pageListener() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;

    // We are transitioning if the page is not an integer
    final isPageTransitioning = page != page.roundToDouble();
    if (_isTransitioning.value != isPageTransitioning) {
      _isTransitioning.value = isPageTransitioning;
    }
  }

  @override
  void initState() {
    super.initState();
    // If we have a roomId, we start on the chat page (1).
    // If no roomId OR if we are opening in background, we start on the chat list (0).
    _pageController = PageController(
      initialPage: widget.roomId.isEmpty || widget.openInBackground ? 0 : 1,
    );
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    _isTransitioning.dispose();
    super.dispose();
  }

  /// Animate to a page with consistent Material 3 timing.
  void animateToPage(int page) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      page,
      duration: _kAnimationDuration,
      curve: _kAnimationCurve,
    );
  }

  @override
  void didUpdateWidget(SwipeableChatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 0. Handle background opening (force list view)
    if (widget.openInBackground) {
      if (_pageController.hasClients && (_pageController.page ?? 0) > 0.5) {
        animateToPage(0);
      }
    }
    // If we have a roomId (active room)
    else if (widget.roomId.isNotEmpty) {
      // If the room changed OR if we just tapped the already active room while on the list page
      if (oldWidget.roomId != widget.roomId ||
          (_pageController.hasClients && _pageController.page?.round() == 0)) {
        // Optimistic animation: trigger directly if controller is ready,
        // otherwise wait for post-frame. This removes one frame of delay.
        if (_pageController.hasClients && (_pageController.page ?? 0) < 0.5) {
          animateToPage(1);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients &&
                (_pageController.page ?? 0) < 0.5) {
              animateToPage(1);
            }
          });
        }
      }
    }
    // If the room was cleared externally (e.g. by switching spaces), slide back to list
    else if (widget.roomId.isEmpty && oldWidget.roomId.isNotEmpty) {
      if (_pageController.hasClients && (_pageController.page ?? 0) > 0.5) {
        animateToPage(0);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && (_pageController.page ?? 0) > 0.5) {
            animateToPage(0);
          }
        });
      }
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
          animateToPage(0);
        } else {
          // If we are already at the list, we can allow the app to go back (e.g. to home)
          context.pop();
        }
      },
      child: SwipeableChatLayoutTransition(
        isTransitioning: _isTransitioning,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: NotificationListener<Notification>(
            onNotification: (notification) {
              if (notification is SwipeBackNotification) {
                animateToPage(0);
                return true;
              }
              if (notification is ShowChatNotification) {
                animateToPage(1);
                return true;
              }
              return false;
            },
            child: PageView(
              controller: _pageController,
              physics: const _SnappyPageScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                _KeepAliveWrapper(
                  child: RepaintBoundary(
                    child: ChatList(
                      activeChat: widget.roomId.isEmpty ? null : widget.roomId,
                      activeSpace: spaceId,
                      displayNavigationRail: true,
                      openInBackground: widget.openInBackground,
                    ),
                  ),
                ),
                _KeepAliveWrapper(
                  child: RepaintBoundary(child: widget.chatPage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
