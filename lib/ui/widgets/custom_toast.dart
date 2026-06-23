import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CustomToast {
  void showToast(String body,{bool isCenter=false}) {
    Fluttertoast.showToast(
        msg: body,
        toastLength: Toast.LENGTH_SHORT,
        gravity: isCenter ? ToastGravity.CENTER : ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        // backgroundColor: error?colors.errorColor:colors.success,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0);
  }
}
