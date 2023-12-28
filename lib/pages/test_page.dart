import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:obtainiumi/providers/apps_provider.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';

class TestPage extends StatefulWidget{
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {

  Queue<DownloadNotification> notificationQueue = Queue();

  Future<void> testDownloadNotify(NotificationsProvider notificationsProvider, AppsProvider appsProvider)async {
    notificationsProvider.onDidReceiveNotificationResponse = (action) {
      debugPrint("Notification Received ${action.actionId}");
      if(action.actionId == "cancel") {
        appsProvider.cancelFlag = true;
      }
    };
    for(int i = 0; i < 10; i++) {
      if(appsProvider.cancelFlag){
        break;
      }
      var notify = DownloadNotification("Test App", i * 10);
      notificationsProvider.notify(notify);
      // notificationQueue.add(notify);
      await Future.delayed(Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Page"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Test Show Download Notification"),
            onTap: () {
              testDownloadNotify(context.read<NotificationsProvider>(), context.read<AppsProvider>());
            },
          ),
          ListTile(
            title: const Text("Test Dismiss Download Notification"),
            onTap: () {
              if(notificationQueue.isNotEmpty) {
                context.read<NotificationsProvider>().cancel(notificationQueue.removeFirst().id);
              }
            },
          )
        ],
      ),
    );
  }
}