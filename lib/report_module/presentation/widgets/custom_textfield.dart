import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChange;
  final String hintText;
  final int? maxLine;
  final int? maxCharacter;
  final bool required;
  final bool showLabel;
  final bool readOnly;

  final double verticalPadding;
  final TextInputType inputType;
  final Function? onValidate;
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.required = false,
    this.maxLine,
    this.readOnly = false,
    this.verticalPadding = 13,
    this.inputType = TextInputType.text,
    this.onValidate,
    this.onChange,
    this.showLabel = false,
    this.maxCharacter,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLines: maxLine,
      controller: controller,
      onChanged: onChange,
      style:
          CustomTextStyle.reportTitle.copyWith(fontWeight: FontWeight.normal),
      cursorColor: Colors.black,
      maxLength: maxCharacter,
      cursorHeight: 12,
      validator: (v) {
        if (v!.isEmpty && required) return "$hintText is required*";
        if (onValidate != null) return onValidate!();
        return null;
      },
      readOnly: readOnly,
      keyboardType: inputType,
      decoration: InputDecoration(
          labelText: showLabel ? hintText : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
                color: CustomColors.black.withValues(alpha: .1),
                width: .5), // Removes border
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
                color: CustomColors.blue, width: 1), // Removes border
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
                color: CustomColors.black.withValues(alpha: .1),
                width: .5), // Removes border
          ),
          filled: true,
          fillColor: CustomColors.containerColor,
          hintStyle: CustomTextStyle.reportTitle.copyWith(
              fontWeight: FontWeight.normal,
              color: CustomColors.black.withValues(alpha: .4)),
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 15, vertical: verticalPadding),
          labelStyle: CustomTextStyle.reportTitle.copyWith(
              fontWeight: FontWeight.normal,
              color: CustomColors.black.withValues(alpha: .4)),
          hintText: hintText),
    );
  }
}
