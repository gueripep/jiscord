import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/start_chat_fab.dart';
import 'package:fluffychat/pages/chat/swipeable_chat_layout.dart';
import 'package:fluffychat/widgets/navigation_rail.dart';
import 'chat_list_body.dart';

class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: FluffyThemes.isColumnMode(context) && !controller.isSearchMode,
      onPopInvokedWithResult: (pop, _) {
        if (pop) return;

        // If we are in swipeable mode, only handle back if we are actually
        // on the list page (index 0). If we are on the chat page (index 1),
        // we let ChatPage's PopScope handle it.
        final transition = SwipeableChatLayoutTransition.maybeOf(context);
        if (transition != null && transition.currentPage.value > 0.5) return;

        if (controller.isSearchMode) {
          controller.cancelSearch();
          return;
        }
        // If we are at the root list and not searching, exit the app.
        // We use SystemNavigator.pop() to ensure the app closes even if there
        // is history from switching spaces.
        if (!FluffyThemes.isColumnMode(context)) {
          SystemNavigator.pop();
        }
      },
      child: Row(
        children: [
          if (FluffyThemes.isColumnMode(context) ||
              AppSettings.displayNavigationRail.value ||
              controller.widget.displayNavigationRail) ...[
            SpacesNavigationRail(
              activeSpaceId: controller.activeSpaceId,
              onGoToChats: controller.clearActiveSpace,
              onGoToSpaceId: controller.setActiveSpace,
            ),
            Container(color: Theme.of(context).dividerColor, width: 1),
          ],
          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                body: ChatListViewBody(controller),
                floatingActionButton:
                    !controller.isSearchMode &&
                        controller.activeSpaceId == null &&
                        !FluffyThemes.isColumnMode(context)
                    ? StartChatFab()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
