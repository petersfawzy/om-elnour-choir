import 'package:flutter/material.dart';

snack({required String txt, Color color = Colors.red}) {
  return SnackBar(
    content: Text(
      txt,
    ),
    duration: const Duration(seconds: 3),
    backgroundColor: color,
  );
}
