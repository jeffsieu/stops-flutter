part of 'bus_stop_sheet_bloc.dart';

class BusStopSheetEvent {
  const BusStopSheetEvent();
}

class SheetRequested extends BusStopSheetEvent {
  final BusStop busStop;
  final int routeId;
  final bool withEdit;

  const SheetRequested(this.busStop, this.routeId) : withEdit = false;
  const SheetRequested.withEdit(this.busStop, this.routeId) : withEdit = true;
}

class SheetHidden extends BusStopSheetEvent {
  const SheetHidden();
}

class EditModeEntered extends BusStopSheetEvent {
  const EditModeEntered();
}

class EditModeExited extends BusStopSheetEvent {
  const EditModeExited();
}

class RenameRequested extends BusStopSheetEvent {
  const RenameRequested();
}

class RenameExited extends BusStopSheetEvent {
  const RenameExited();
}

class BusStopRenamed extends BusStopSheetEvent {
  final String newName;

  const BusStopRenamed(this.newName);
}
