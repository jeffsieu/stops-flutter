

import 'package:flutter/material.dart';

class ReorderStatusNotification extends Notification {
  ReorderStatusNotification(this.isReordering);
  final bool isReordering;
}