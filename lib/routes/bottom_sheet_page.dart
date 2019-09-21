import 'package:flutter/material.dart';

import 'package:rubber/rubber.dart';

import '../utils/bus_stop.dart';
import '../widgets/bus_stop_detail_sheet.dart';

abstract class BottomSheetPage extends StatefulWidget {
  final GlobalKey<BusStopDetailSheetState> bottomSheetKey = GlobalKey();
}

abstract class BottomSheetPageState<T extends BottomSheetPage> extends State<T> with TickerProviderStateMixin<T> {
  bool initialized = false;
  RubberAnimationController rubberAnimationController;
  ScrollController sheetScrollController;
  BusStopDetailSheet busStopDetailSheet;

  @override
  void dispose() {
    if (sheetScrollController != null)
      sheetScrollController.dispose();
    super.dispose();
  }

  void buildSheet({@required bool isHomePage}) {
    /* Initialize rubber sheet */
    if (widget.bottomSheetKey.currentState == null) {
      busStopDetailSheet =
          BusStopDetailSheet(
              key: widget.bottomSheetKey, vsync: this, isHomePage: isHomePage);
      rubberAnimationController = busStopDetailSheet.rubberAnimationController;
      sheetScrollController = busStopDetailSheet.scrollController;
      initialized = true;
    }
  }

  Widget bottomSheet({@required Widget child}) {
    return RubberBottomSheet(
      scrollController: sheetScrollController,
      animationController: rubberAnimationController,
      lowerLayer: child,
      upperLayer: busStopDetailSheet,
    );
  }

  @mustCallSuper
  void showBusDetailSheet(BusStop busStop) {
    widget.bottomSheetKey.currentState.updateWith(busStop);
  }
}