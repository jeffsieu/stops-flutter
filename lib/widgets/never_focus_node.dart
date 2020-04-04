import 'package:flutter/material.dart';

class NeverFocusNode extends FocusNode {
  @override
  bool get hasFocus {
    return false;
  }
}