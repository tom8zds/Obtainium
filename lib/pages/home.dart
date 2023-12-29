import 'package:animations/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obtainiumi/pages/add_app.dart';
import 'package:obtainiumi/pages/apps.dart';
import 'package:obtainiumi/pages/import_export.dart';
import 'package:obtainiumi/pages/settings.dart';
import 'package:obtainiumi/providers/apps_provider.dart';
import 'package:obtainiumi/providers/settings_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class NavigationPageItem {
  late String title;
  late IconData icon;
  late Widget widget;

  NavigationPageItem(this.title, this.icon, this.widget);
}

class _HomePageState extends State<HomePage> {
  List<int> selectedIndexHistory = [];
  bool isReversing = false;
  int prevAppCount = -1;
  bool prevIsLoading = true;

  List<NavigationPageItem> pages = [
    NavigationPageItem(tr('appsString'), Icons.apps,
        AppsPage(key: GlobalKey<AppsPageState>())),
    NavigationPageItem(tr('addApp'), Icons.add, const AddAppPage()),
    NavigationPageItem(
        tr('importExport'), Icons.import_export, const ImportExportPage()),
    NavigationPageItem(tr('settings'), Icons.settings, const SettingsPage())
  ];

  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    AppsProvider appsProvider = context.watch<AppsProvider>();
    SettingsProvider settingsProvider = context.watch<SettingsProvider>();

    setIsReversing(int targetIndex) {
      bool reversing = selectedIndexHistory.isNotEmpty &&
          selectedIndexHistory.last > targetIndex;
      setState(() {
        isReversing = reversing;
      });
    }

    switchToPage(int index) async {
      setIsReversing(index);
      if (index == 0) {
        while ((pages[0].widget.key as GlobalKey<AppsPageState>).currentState !=
            null) {
          // Avoid duplicate GlobalKey error
          await Future.delayed(const Duration(microseconds: 1));
        }
        setState(() {
          selectedIndexHistory.clear();
        });
      } else if (selectedIndexHistory.isEmpty ||
          (selectedIndexHistory.isNotEmpty &&
              selectedIndexHistory.last != index)) {
        setState(() {
          int existingInd = selectedIndexHistory.indexOf(index);
          if (existingInd >= 0) {
            selectedIndexHistory.removeAt(existingInd);
          }
          selectedIndexHistory.add(index);
        });
      }
    }

    if (!prevIsLoading &&
        prevAppCount >= 0 &&
        appsProvider.apps.length > prevAppCount &&
        selectedIndexHistory.isNotEmpty &&
        selectedIndexHistory.last == 1) {
      switchToPage(0);
    }
    prevAppCount = appsProvider.apps.length;
    prevIsLoading = appsProvider.loadingApps;

    return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: PageTransitionSwitcher(
            duration: Duration(
                milliseconds:
                    settingsProvider.disablePageTransitions ? 0 : 300),
            reverse: settingsProvider.reversePageTransitions
                ? !isReversing
                : isReversing,
            transitionBuilder: (
              Widget child,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              );
            },
            child: pages
                .elementAt(selectedIndexHistory.isEmpty
                    ? 0
                    : selectedIndexHistory.last)
                .widget,
          ),
          bottomNavigationBar: NavigationBar(
            destinations: pages
                .map((e) =>
                    NavigationDestination(icon: Icon(e.icon), label: e.title))
                .toList(),
            onDestinationSelected: (int index) async {
              HapticFeedback.selectionClick();
              switchToPage(index);
            },
            selectedIndex:
                selectedIndexHistory.isEmpty ? 0 : selectedIndexHistory.last,
          ),
        ),
        onPopInvoked: (bool didPop) async {
          if (didPop) {
            return;
          }
          setIsReversing(selectedIndexHistory.length >= 2
              ? selectedIndexHistory.reversed.toList()[1]
              : 0);
          if (selectedIndexHistory.isNotEmpty) {
            setState(() {
              selectedIndexHistory.removeLast();
            });
            return;
          }
          bool flag = !(pages[0].widget.key as GlobalKey<AppsPageState>)
              .currentState
              ?.clearSelected();
          if (flag) {
            DateTime now = DateTime.now();
            if (currentBackPressTime == null ||
                now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
              currentBackPressTime = now;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("再次返回以退出应用")));
              return;
            }
            SystemNavigator.pop();
          }
        });
  }
}
