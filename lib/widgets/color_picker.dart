import 'package:flutter/material.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    required this.colors,
    required this.size,
    required this.onColorChanged,
    this.initialColor,
    this.spacing,
    this.runSpacing,
    this.shape = const CircleBorder(),
    Key? key,
  }) : super(key: key);

  final double size;
  final List<Color> colors;
  final Color? initialColor;
  final void Function(Color) onColorChanged;
  final double? spacing;
  final double? runSpacing;
  final ShapeBorder shape;

  @override
  _ColorPickerState createState() {
    return _ColorPickerState();
  }
}

class _ColorPickerState extends State<ColorPicker> {
  Color? selectedColor;

  @override
  void initState() {
    super.initState();
    assert(widget.colors.isNotEmpty, 'colors cannot be empty');
    if (widget.initialColor != null) {
      assert(widget.colors.contains(widget.initialColor),
          'colors must contain initial color');
    }
    selectedColor = widget.initialColor ?? widget.colors[0];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing ?? 8.0,
      runSpacing: widget.runSpacing ?? 8.0,
      children: <Widget>[
        for (Color color in widget.colors) buildColorWidget(color),
      ],
    );
  }

  Widget buildColorWidget(Color color) {
    final bool isSelected = color == selectedColor;
    return Material(
      color: color,
      shape: widget.shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onColorTapped(color),
        child: Stack(
          children: <Widget>[
            SizedBox(
              width: widget.size,
              height: widget.size,
            ),
            if (isSelected)
              Positioned.fill(
                child: Center(
                  child: Icon(Icons.done_rounded,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onColorTapped(Color color) {
    setState(() {
      selectedColor = color;
      widget.onColorChanged(color);
    });
  }
}
