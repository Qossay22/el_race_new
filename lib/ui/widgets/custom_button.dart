import 'package:el_race/resources/app_colors.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // This makes the button full width
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.black, backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Text color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: const BorderSide(color: AppColors.black, width: 0.1),
          elevation: 5,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
