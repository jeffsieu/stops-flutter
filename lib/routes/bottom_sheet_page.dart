import 'package:flutter/material.dart';

import 'package:rubber/rubber.dart';

import '../models/bus_stop.dart';
import '../models/user_route.dart';
import '../widgets/bus_stop_detail_sheet.dart';

abstract class BottomSheetPage extends StatefulWidget {
  final GlobalKey<BusStopDetailSheetState> bottomSheetKey = GlobalKey();

  BottomSheetPage({Key? key}) : super(key: key);

  static BottomSheetPageState<BottomSheetPage>? of(BuildContext context) =>
      context.findAncestorStateOfType<BottomSheetPageState<BottomSheetPage>>();
}

abstract class BottomSheetPageState<T extends BottomSheetPage> extends State<T>
    with TickerProviderStateMixin<T> {
  bool initialized = false;
  RubberAnimationController get rubberAnimationController =>
      busStopDetailSheet.rubberAnimationController;
  ScrollController get sheetScrollController =>
      busStopDetailSheet.scrollController;
  late BusStopDetailSheet busStopDetailSheet;

  @override
  void dispose() {
    sheetScrollController.dispose();
    super.dispose();
  }

  void buildSheet({required bool hasAppBar}) {
    /* Initialize rubber sheet */
    if (widget.bottomSheetKey.currentState == null) {
      busStopDetailSheet = BusStopDetailSheet(
          key: widget.bottomSheetKey, vsync: this, hasAppBar: hasAppBar);
      initialized = true;
    }
  }

  Widget bottomSheet({required Widget child}) {
    return RubberBottomSheet(
      scrollController: sheetScrollController,
      animationController: rubberAnimationController,
      lowerLayer: child,
      upperLayer: busStopDetailSheet,
    );
  }

  bool isBusDetailSheetVisible() {
    return rubberAnimationController.value > 0;
  }

  @mustCallSuper
  Future<void> showBusStopDetailSheet(BusStop busStop, StoredUserRoute route) async {
    await widget.bottomSheetKey.currentState?.updateWith(busStop, route);
  }

  @mustCallSuper
  Future<void> hideBusStopDetailSheet() async {
    await rubberAnimationController.animateTo(
        to: rubberAnimationController.lowerBound!);
    await widget.bottomSheetKey.currentState?.updateWith(null, null);
  }

  void edit() {
    widget.bottomSheetKey.currentState?.edit();
  }
}
