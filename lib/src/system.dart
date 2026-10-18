// What the app asks of the desktop outside its windows: opening a link, a notification when
// a background window rings the bell. Tests use [FakeSystem].

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:silica_ui/silica_ui.dart';

abstract class SystemActions {
  /// The user's home directory, if known.
  String? get home;

  /// Opens a URL (or a path) with the default application.
  Future<void> open(String target);

  /// Shows a desktop notification.
  Future<void> notify(String title, String body);
}

/// The real desktop: `xdg-open`, the notification service on the session bus.
class DesktopSystem implements SystemActions {
  DesktopSystem([Map<String, String>? environment])
    : _env = environment ?? Platform.environment;

  final Map<String, String> _env;

  @override
  String? get home => _env['HOME'];

  @override
  Future<void> open(String target) async {
    try {
      await Process.start('xdg-open', [
        target,
      ], mode: ProcessStartMode.detached);
    } on Object {
      // No xdg-open: nothing to open it with.
    }
  }

  @override
  Future<void> notify(String title, String body) async {
    try {
      await SilicaDBus.instance.call(
        destination: 'org.freedesktop.Notifications',
        path: '/org/freedesktop/Notifications',
        interface: 'org.freedesktop.Notifications',
        method: 'Notify',
        signature: 'susssasa{sv}i',
        args: [
          'Terminal',
          0,
          'utilities-terminal',
          title,
          body,
          <String>[],
          <String, Object?>{},
          5000,
        ],
      );
    } on PlatformException {
      // No notification service.
    } on MissingPluginException {
      // Outside Silica.
    }
  }
}

/// Records instead of acting.
class FakeSystem implements SystemActions {
  FakeSystem({this.home});

  @override
  final String? home;
  final List<String> opened = [];
  final List<(String, String)> notifications = [];

  @override
  Future<void> open(String target) async => opened.add(target);

  @override
  Future<void> notify(String title, String body) async =>
      notifications.add((title, body));
}
