import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../utils/database_utils.dart';
import '../bloc/bus_stop_sheet_bloc.dart';

class BusStopSheetHeaderDropdown extends StatelessWidget {
  const BusStopSheetHeaderDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEditing =
        context.select((BusStopSheetBloc bloc) => bloc.state.isEditing);
    final isInRoute =
        context.select((BusStopSheetBloc bloc) => bloc.state.isInRoute);
    final busStop =
        context.select((BusStopSheetBloc bloc) => bloc.state.busStop)!;
    final routeId =
        context.select((BusStopSheetBloc bloc) => bloc.state.routeId)!;

    if (isEditing) {
      return IconButton(
        tooltip: 'Save',
        icon: const Icon(Icons.done_rounded),
        color: Theme.of(context).colorScheme.secondary,
        onPressed: () {
          context.read<BusStopSheetBloc>().add(const EditModeExited());
        },
      );
    }
    return PopupMenuButton<_MenuOption>(
      icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).hintColor),
      onSelected: (_MenuOption option) {
        switch (option) {
          case _MenuOption.edit:
            context.read<BusStopSheetBloc>().add(const EditModeEntered());
            break;
          case _MenuOption.rename:
            context.read<BusStopSheetBloc>().add(const RenameRequested());
            break;
          case _MenuOption.favorite:
            if (!isInRoute) {
              addBusStopToRouteWithId(busStop, routeId, context);
            } else {
              removeBusStopFromRoute(busStop, routeId, context);
            }
            break;
          case _MenuOption.googleMaps:
            launchUrlString(
                'geo:${busStop.latitude},${busStop.longitude}?q=${busStop.defaultName} ${busStop.code}');
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_MenuOption>>[
        const PopupMenuItem<_MenuOption>(
          value: _MenuOption.rename,
          child: Text('Rename'),
        ),
        if (isInRoute) const PopupMenuDivider(),
        if (isInRoute)
          const PopupMenuItem<_MenuOption>(
            value: _MenuOption.edit,
            child: Text('Manage pinned services'),
          ),
        PopupMenuItem<_MenuOption>(
          value: _MenuOption.favorite,
          child: Text(isInRoute
              ? routeId == kDefaultRouteId
                  ? 'Unpin from home'
                  : 'Remove from route'
              : 'Pin to home'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_MenuOption>(
          value: _MenuOption.googleMaps,
          child: Text('Open in Google Maps'),
        ),
      ],
    );
  }
}

enum _MenuOption { edit, favorite, googleMaps, rename }
