import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bus_stop.dart';
import '../../utils/database_utils.dart';

part 'bus_stop_sheet_event.dart';

class BusStopSheetBloc extends Bloc<BusStopSheetEvent, BusStopSheetState> {
  BusStopSheetBloc({required this.ref}) : super(BusStopSheetState.initial()) {
    on<SheetRequested>(_onSheetRequested);
    on<SheetHidden>(_onSheetHidden);
    on<EditModeEntered>(_onEditModeEntered);
    on<EditModeExited>(_onEditModeExited);
    on<RenameRequested>(_onRenameRequested);
    on<RenameExited>(_onRenameExited);
    on<BusStopRenamed>(_onBusStopRenamed);
  }

  final WidgetRef ref;

  Future<void> _onSheetRequested(
      SheetRequested event, Emitter<BusStopSheetState> emit) async {
    final busStop = event.busStop;
    final routeId = event.routeId;

    emit(state.copyWith(
      busStop: busStop,
      routeId: routeId,
      visible: true,
      isEditing: event.withEdit,
      isRenaming: false,
      latestOpenTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    /// TODO: Make it await until the sheet is fully open
  }

  void _onSheetHidden(SheetHidden event, Emitter<BusStopSheetState> emit) {
    emit(state.copyWith(
      visible: false,
      isRenaming: false,
      isEditing: false,
    ));
  }

  void _onEditModeEntered(
      EditModeEntered event, Emitter<BusStopSheetState> emit) {
    emit(state.copyWith(isEditing: true));
  }

  void _onEditModeExited(
      EditModeExited event, Emitter<BusStopSheetState> emit) {
    emit(state.copyWith(isEditing: false));
  }

  void _onRenameRequested(
      RenameRequested event, Emitter<BusStopSheetState> emit) {
    emit(state.copyWith(isRenaming: true));
  }

  void _onRenameExited(RenameExited event, Emitter<BusStopSheetState> emit) {
    emit(state.copyWith(isRenaming: false));
  }

  void _onBusStopRenamed(
      BusStopRenamed event, Emitter<BusStopSheetState> emit) {
    if (state.busStop == null) {
      return;
    }
    final newBusStop = state.busStop!.copyWith(displayName: event.newName);

    ref.read(busStopListProvider.notifier).updateBusStop(newBusStop);

    emit(state.copyWith(
      busStop: newBusStop,
    ));
  }
}

class BusStopSheetState {
  final BusStop? busStop;
  final int? routeId;
  final bool visible;
  final bool isEditing;
  final bool isRenaming;

  /// The timestamp of the last time the sheet was opened.
  /// Used to force the state to be different when the sheet is opened again.
  final int latestOpenTimestamp;

  BusStopSheetState.initial()
      : busStop = null,
        routeId = null,
        visible = false,
        isEditing = false,
        isRenaming = false,
        latestOpenTimestamp = 0;
  BusStopSheetState({
    required this.busStop,
    required this.routeId,
    required this.visible,
    required this.isEditing,
    required this.isRenaming,
    required this.latestOpenTimestamp,
  });

  BusStopSheetState copyWith({
    BusStop? busStop,
    int? routeId,
    bool? visible,
    bool? isEditing,
    bool? isRenaming,
    int? latestOpenTimestamp,
  }) {
    return BusStopSheetState(
      busStop: busStop ?? this.busStop,
      routeId: routeId ?? this.routeId,
      visible: visible ?? this.visible,
      isEditing: isEditing ?? this.isEditing,
      isRenaming: isRenaming ?? this.isRenaming,
      latestOpenTimestamp: latestOpenTimestamp ?? this.latestOpenTimestamp,
    );
  }
}
