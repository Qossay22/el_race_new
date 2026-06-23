import 'package:flutter/material.dart';

class HomeDialogs {
  static showBabyGirlPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha((0.5 * 255).toInt()),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white.withAlpha((0.95 * 255).toInt()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "🎉 Congratulations ✨",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Congratulations to",
                  style: TextStyle(fontSize: 13, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                const Text(
                  "Eng. Hassan Abuebied",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  "on the arrival of his baby girl! 🎀✨ Wishing her a life filled with love, joy, and endless blessings. May she bring happiness and prosperity to the family! 💖👶🏼",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/png/Baby_girl.png',
                  height: 80,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}