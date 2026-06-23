import 'package:flutter/material.dart';

class ProfileBoxProvider extends ChangeNotifier {
  bool _isProfileVisible = false;
  bool _muteNotifications = false;

  bool get isProfileVisible => _isProfileVisible;
  bool get muteNotifications => _muteNotifications;

  void toggleProfileBox() {
    _isProfileVisible = !_isProfileVisible;
    notifyListeners();
  }

  void hideProfileBox() {
    _isProfileVisible = false;
    notifyListeners();
  }

  void toggleMuteNotifications() {
    _muteNotifications = !_muteNotifications;
    notifyListeners();
  }

  void setMuteNotifications(bool value) {
    _muteNotifications = value;
    notifyListeners();
  }
}
