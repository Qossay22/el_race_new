import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter/material.dart';

void showLeftToRightPopupClean({
  required BuildContext context,
  required LoginResponseModel loginResponseModel,
  required bool isCheckedIn,
  required VoidCallback onConfirmed,
  required VoidCallback onCancelled,
}) {
  // The backend matches the user to the nearest project using the coordinates
  // sent in the check-in/out API call — no manual project selection needed.
  onConfirmed();
}
