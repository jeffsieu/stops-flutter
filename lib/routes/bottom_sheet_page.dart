  import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubber/rubber.dart';

import '../bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import '../bus_stop_sheet/widgets/bus_stop_sheet.dart';

abstract class BottomSheetPage extends StatefulWidget {
  const BottomSheetPage({Key? key}) : super(key: key);

  static BottomSheetPageState<BottomSheetPage>? of(BuildContext context) =>
      context.findAncestorStateOfType<BottomSheetPageState<BottomSheetPage>>();
}

abstract class BottomSheetPageState<T extends BottomSheetPage> extends State<T>
    with TickerProviderStateMixin<T> {
  BottomSheetPageState({required this.hasAppBar});

  RubberAnimationController get rubberAnimationController =>
      busStopSheet.rubberAnimationController;
  ScrollController get sheetScrollController => busStopSheet.scrollController;

  late final BusStopSheet busStopSheet =
      BusStopSheet(vsync: this, hasAppBar: hasAppBar);

  final bool hasAppBar;

  @override
  void dispose() {
    sheetScrollController.dispose();
    super.dispose();
  }

  Widget bottomSheet({required Widget child}) {
    return BlocProvider(
      create: (context) => BusStopSheetBloc(),
      child: RubberBottomSheet(
        scrollController: sheetScrollController,
        animationController: rubberAnimationController,
        upperLayer: busStopSheet,
        lowerLayer: child,
      ),
    );
  }

  bool isBusDetailSheetVisible() {
    return rubberAnimationController.value > 0;
  }

  @mustCallSuper
  Future<void> hideBusStopDetailSheet() async {
    await rubberAnimationController.animateTo(
        to: rubberAnimationController.lowerBound!);

    /// TODO
    // await updateWith(null, null);
  }
}
