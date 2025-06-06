import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

field({
  required String label,
  required IconData icon,
  required TextEditingController controller,
  required TextInputType textInputType,
  required TextInputAction textInputAction,
  Widget suffixIcon = const SizedBox(),
  bool isSecure = false,
  List<TextInputFormatter> formaters = const [],
  bool isEnabled = true,
  Color iconColor = Colors.grey,
  Color textColor = Colors.white, // إضافة معلمة لون النص مع قيمة افتراضية
}) {
  return TextField(
    controller: controller,
    style: TextStyle(color: textColor), // إضافة نمط النص مع لون النص المحدد
    decoration: InputDecoration(
      border: _inputBorder(Colors.amberAccent),
      focusedBorder: _inputBorder(Colors.amberAccent),
      errorBorder: _inputBorder(Colors.red),
      focusedErrorBorder: _inputBorder(Colors.red),
      labelText: label,
      labelStyle: TextStyle(
          color: textColor
              .withOpacity(0.8)), // إضافة نمط التسمية مع لون النص المحدد
      prefixIcon: Icon(icon, color: Colors.grey, size: 20.0),
      suffixIcon: suffixIcon,
    ),
    obscureText: isSecure,
    textInputAction: textInputAction,
    keyboardType: textInputType,
    inputFormatters: formaters,
    enabled: isEnabled,
  );
}

OutlineInputBorder _inputBorder(Color color) {
  return OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color, width: 0.5));
}
