
import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/utils/extensions/size_extension.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final GlobalKey formFieldKey;
  final String validatorText;

  const CustomTextField({
    super.key,
    required this.formFieldKey,
    required this.controller,
    required this.hintText,
    required this.validatorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric( vertical: 0.02.sh),
      child: TextFormField(
          key: formFieldKey,
          controller: controller,
          cursorColor: AppColors.black,
          style: const TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.6,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColors.gray600,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.6,
            ),
            fillColor: AppColors.primaryBlack,
              filled: true,
            border: const OutlineInputBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16), // Rounded bottom only
            ),
          ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16),),
              borderSide: BorderSide(color: AppColors.red),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16),),
              borderSide: BorderSide(color: AppColors.grey),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16),),
              borderSide: BorderSide(color: AppColors.black),
            ),



          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return "Name cannot be empty";
            } else {
              return null;
            }
          }),
    );
  }
}
