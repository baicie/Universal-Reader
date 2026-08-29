import 'package:flutter/widgets.dart';

bool useNativeVisualRenderer() {
  return !WidgetsBinding.instance.runtimeType.toString().contains('Test');
}
