// @dart=2.9

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/src/util/handler.dart';

/* MAKESHIFT CLASS TO FIX BUG WITH LIBRARY */

class CustomHandle extends StatefulWidget {
  const CustomHandle({
    Key key,
    @required this.child,
    this.delay = Duration.zero,
    this.vibrate = true,
  })  : assert(delay != null),
        assert(child != null),
        assert(vibrate != null),
        super(key: key);

  final Widget child;
  final Duration delay;

  final bool vibrate;

  @override
  _HandleState createState() => _HandleState();
}

class _HandleState extends State<CustomHandle> {
  // A custom handler used to cancel the pending onDragStart callbacks.
  Handler _handler;
  // The parent Reorderable item.
  ReorderableState _reorderable;
  // The parent list.
  ImplicitlyAnimatedReorderableListState _list;
  // Whether the ImplicitlyAnimatedReorderableList has a
  // scrollDirection of Axis.vertical.
  bool get _isVertical => _list?.isVertical ?? true;

  bool _inDrag = false;

  double _initialOffset;
  double _currentOffset;
  double get _delta => (_currentOffset ?? 0) - (_initialOffset ?? 0);

  final double _deltaThreshold = 4.0;
  double _currentDelta = 0.0;

  void _onDragStarted(Offset pointer) {
    _removeScrollListener();

    _inDrag = true;
    _initialOffset = _isVertical ? pointer.dy : pointer.dx;

    _list?.onDragStarted(_reorderable?.key);
    _reorderable.rebuild();

    _vibrate();
  }

  void _onDragUpdated(Offset pointer, bool upward) {
    _currentOffset = _isVertical ? pointer.dy : pointer.dx;
    _list?.onDragUpdated(_delta);
  }

  void _onDragEnded() {
    _inDrag = false;

    _handler?.cancel();
    _list?.onDragEnded();
  }

  void _vibrate() {
    if (widget.vibrate) HapticFeedback.mediumImpact();
  }

  // A Handle should only initiate a reorder when the list didn't change it scroll
  // position in the meantime.

  void _addScrollListener() {
    if (widget.delay > Duration.zero) {
      _list?.scrollController?.addListener(_cancelReorder);
    }
  }

  void _removeScrollListener() {
    if (widget.delay > Duration.zero) {
      _list?.scrollController?.removeListener(_cancelReorder);
    }
  }

  void _cancelReorder() {
    _handler?.cancel();
    _removeScrollListener();
    _currentDelta = 0.0;

    if (_inDrag) _onDragEnded();
  }

  @override
  Widget build(BuildContext context) {
    _list ??= ImplicitlyAnimatedReorderableList.of(context);
    assert(_list != null,
        'No ancestor ImplicitlyAnimatedReorderableList was found in the hierarchy!');
    _reorderable ??= Reorderable.of(context);
    assert(_reorderable != null,
        'No ancestor Reorderable was found in the hierarchy!');

    return Listener(
      onPointerDown: (PointerDownEvent event) {
        final Offset pointer = event.localPosition;

        if (!_inDrag) {
          _cancelReorder();

          _addScrollListener();
          _handler = postDuration(
            widget.delay,
            () => _onDragStarted(pointer),
          );
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        final Offset pointer = event.localPosition;
        final double delta = _isVertical ? event.delta.dy : event.delta.dx;

        _currentDelta += delta;
        if (!_inDrag && _currentDelta.abs() > _deltaThreshold) {
          _cancelReorder();
        }

        if (_inDrag) _onDragUpdated(pointer, delta.isNegative);
      },
      onPointerUp: (_) => _cancelReorder(),
      onPointerCancel: (_) => _cancelReorder(),
      child: widget.child,
    );
  }
}
