import 'package:meta/meta.dart';

import 'package:flutter/material.dart';

import '../routes/search_page.dart';
import '../utils/bus_stop.dart';
import '../utils/shared_preferences_utils.dart';

class BusStopSearchItem extends StatefulWidget {
  const BusStopSearchItem({
    @required Key key,
    @required this.codeStart,
    @required this.codeBold,
    @required this.codeEnd,
    @required this.nameStart,
    @required this.nameBold,
    @required this.nameEnd,
    @required this.distance,
    @required this.busStop,
  }) : super (key: key);

  final String codeStart;
  final String codeBold;
  final String codeEnd;
  final String nameStart;
  final String nameBold;
  final String nameEnd;
  final String distance;
  final BusStop busStop;

  @override
  State<StatefulWidget> createState() {
    return BusStopSearchItemState();
  }
}

class BusStopSearchItemState extends State<BusStopSearchItem> with SingleTickerProviderStateMixin {
  bool _isStarEnabled = false;

  @override
  void initState() {
    super.initState();
    isBusStopStarred(widget.busStop).then((bool contains) {
      if (mounted)
        setState(() {
          _isStarEnabled = contains;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _showDetailSheet(context, widget.busStop),
      leading: Text(widget.distance),
      title: RichText(
        text: TextSpan(
          text: widget.nameStart,
          style: Theme.of(context)
              .textTheme
              .title
              .copyWith(fontWeight: FontWeight.normal),
          children: <TextSpan>[
            TextSpan(
                text: widget.nameBold,
                style: Theme.of(context).textTheme.title.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).textTheme.body1.color,
                  background: Paint()
                    ..color =
                        Theme.of(context).highlightColor,
                )),
            TextSpan(
                text: widget.nameEnd),
          ],
        ),
      ),
      subtitle: RichText(
        text: TextSpan(
          text: widget.codeStart,
          style: Theme.of(context)
              .textTheme
              .subtitle
              .copyWith(fontWeight: FontWeight.normal),
          children: <TextSpan>[
            TextSpan(
                text: widget.codeBold,
                style: Theme.of(context).textTheme.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).textTheme.body1.color,
                  background: Paint()
                    ..color =
                        Theme.of(context).highlightColor,
                )),
            TextSpan(
                text: widget.codeEnd),
          ],
        ),
      ),
      trailing: IconButton(
        icon: Icon(_isStarEnabled ? Icons.star : Icons.star_border),
        tooltip: _isStarEnabled ? 'Unfavorite' : 'Favorite',
        onPressed: () {
          setState(() {
            _isStarEnabled = !_isStarEnabled;
          });
          if (_isStarEnabled) {
            starBusStop(widget.busStop);
          } else {
            unstarBusStop(widget.busStop);
          }
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context, BusStop busStop) {
    // add to history
    FocusScope.of(context).unfocus();
    Future<void>.delayed(const Duration(milliseconds: 100), () {
        SearchPage.of(context).showBusDetailSheet(busStop);
      }
    );
  }
}