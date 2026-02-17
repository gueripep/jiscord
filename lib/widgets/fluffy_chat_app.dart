import 'package:flutter/material.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluffychat/config/routes.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/app_lock.dart';
import 'package:fluffychat/widgets/theme_builder.dart';
import '../utils/platform_infos.dart';
import '../utils/custom_scroll_behaviour.dart';
import 'matrix.dart';
import 'voice_channel_bar.dart';

class FluffyChatApp extends StatefulWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final String? pincode;
  final SharedPreferences store;

  const FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  /// getInitialLink may rereturn the value multiple times if this view is
  /// opened multiple times for example if the user logs out after they logged
  /// in with qr code or magic link.
  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
  );

  @override
  State<FluffyChatApp> createState() => _FluffyChatAppState();
}

class _FluffyChatAppState extends State<FluffyChatApp> {
  @override
  void initState() {
    super.initState();
    _setHighRefreshRate();
  }

  Future<void> _setHighRefreshRate() async {
    if (PlatformInfos.isAndroid) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        // Fail silently
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeBuilder(
      builder: (context, themeMode, primaryColor) => MaterialApp.router(
        title: AppSettings.applicationName.value,
        themeMode: themeMode,
        theme: FluffyThemes.buildTheme(context, Brightness.light, primaryColor),
        darkTheme: FluffyThemes.buildTheme(
          context,
          Brightness.dark,
          primaryColor,
        ),
        scrollBehavior: CustomScrollBehavior(),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        routerConfig: FluffyChatApp.router,
        builder: (context, child) => AppLockWidget(
          pincode: widget.pincode,
          clients: widget.clients,
          // Need a navigator above the Matrix widget for
          // displaying dialogs
          child: Matrix(
            clients: widget.clients,
            store: widget.store,
            child: Column(
              children: [
                Expanded(
                  child: widget.testWidget ?? child ?? const SizedBox.shrink(),
                ),
                const Material(child: VoiceChannelBar()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
