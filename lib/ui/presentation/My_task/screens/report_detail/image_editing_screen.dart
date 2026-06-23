import 'dart:io';
import 'package:el_race/core/constants/colors.dart';
import 'package:el_race/ui/widgets/square_button.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ImageEditingScreen extends StatefulWidget {
  final File image;
  const ImageEditingScreen({super.key, required this.image});

  @override
  _ImageEditingScreenState createState() => _ImageEditingScreenState();
}

class _ImageEditingScreenState extends State<ImageEditingScreen> {
  String? selectedShape;
  ShapeFactory? selectedShapeFactory;
  static const Color red = Color(0xFFFF0000);
  FocusNode textFocusNode = FocusNode();
  late PainterController controller;
  ui.Image? backgroundImage;
  Paint shapePaint = Paint()
    ..strokeWidth = 5
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void initState() {
    super.initState();
    controller = PainterController(
        settings: PainterSettings(
            text: TextSettings(
              focusNode: textFocusNode,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, color: red, fontSize: 18),
            ),
            freeStyle: const FreeStyleSettings(
              color: red,
              strokeWidth: 5,
            ),
            shape: ShapeSettings(
              paint: shapePaint,
            ),
            scale: const ScaleSettings(
              enabled: true,
              minScale: 1,
              maxScale: 5,
            )));
    controller.addListener(() {
      if (controller.shapeFactory == null && selectedShape != null) {
        controller.shapeFactory = selectedShapeFactory;
        setState(() {});
      }
    });
    textFocusNode.addListener(onFocus);
    initBackground();
  }

  void initBackground() async {
    final image = await FileImage(widget.image).image;
    setState(() {
      backgroundImage = image;
      controller.background = image.backgroundDrawable;
    });
  }

  void onFocus() {
    setState(() {});
  }

  Future<void> sendFinalImageBack() async {
    if (backgroundImage == null) return;
    final imageSize = Size(
      backgroundImage!.width.toDouble(),
      backgroundImage!.height.toDouble(),
    );

    final ui.Image renderedImage = await controller.renderImage(imageSize);

    final ByteData? byteData =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      await File(widget.image.path).writeAsBytes(pngBytes);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Widget buildDefault(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size(double.infinity, kToolbarHeight),
          child: ValueListenableBuilder<PainterControllerValue>(
              valueListenable: controller,
              builder: (context, _, child) {
                return AppBar(
                  automaticallyImplyLeading: false,
                  leading: Align(
                    alignment: Alignment.centerRight,
                    child: SquareButton(
                      icon: Icons.keyboard_backspace,
                      color: CustomColors.white,
                      borderColor: CustomColors.black,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  centerTitle: true,
                  title: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.arrowClockwise(),
                        ),
                        onPressed: controller.canRedo ? redo : null,
                      ),
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.arrowCounterClockwise(),
                        ),
                        onPressed: controller.canUndo ? undo : null,
                      ),
                    ],
                  ),
                  actions: [
                    SquareButton(
                      icon: Icons.text_fields_outlined,
                      color: CustomColors.blue,
                      borderColor: CustomColors.white,
                      onPressed: addText,
                    ),
                    const SizedBox(width: 4),
                    SquareButton(
                      icon: Icons.check,
                      color: CustomColors.maroon,
                      borderColor: CustomColors.white,
                      onPressed: () {
                        if (textFocusNode.hasFocus) {
                          textFocusNode.unfocus();
                          return;
                        }
                        sendFinalImageBack();
                      },
                    ),
                    const SizedBox(
                      width: 12,
                    )
                  ],
                );
              }),
        ),
        body: Stack(
          children: [
            if (backgroundImage != null)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: AspectRatio(
                    aspectRatio:
                        backgroundImage!.width / backgroundImage!.height,
                    child: FlutterPainter(
                      controller: controller,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              child: BottomDock(
                extra: 12,
                liftWithKeyboard: false,
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, _, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 400,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: const BoxDecoration(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                            color: Colors.white54,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.freeStyleMode !=
                                  FreeStyleMode.none) ...[
                                const Divider(),
                                const Text("Free Style Settings"),
                                // Control free style stroke width
                                Row(
                                  children: [
                                    const Expanded(
                                        flex: 1, child: Text("Stroke Width")),
                                    Expanded(
                                      flex: 3,
                                      child: Slider.adaptive(
                                          min: 2,
                                          max: 25,
                                          value:
                                              controller.freeStyleStrokeWidth,
                                          onChanged: setFreeStyleStrokeWidth),
                                    ),
                                  ],
                                ),
                                if (controller.freeStyleMode ==
                                    FreeStyleMode.draw)
                                  Row(
                                    children: [
                                      const Expanded(
                                          flex: 1, child: Text("Color")),
                                      // Control free style color hue
                                      Expanded(
                                        flex: 3,
                                        child: Slider.adaptive(
                                            min: 0,
                                            max: 359.99,
                                            value: HSVColor.fromColor(
                                                    controller.freeStyleColor)
                                                .hue,
                                            activeColor:
                                                controller.freeStyleColor,
                                            onChanged: setFreeStyleColor),
                                      ),
                                    ],
                                  ),
                              ],
                              if (textFocusNode.hasFocus) ...[
                                const Divider(),
                                const Text("Text settings"),
                                // Control text font size
                                Row(
                                  children: [
                                    const Expanded(
                                        flex: 1, child: Text("Font Size")),
                                    Expanded(
                                      flex: 3,
                                      child: Slider.adaptive(
                                          min: 8,
                                          max: 96,
                                          value:
                                              controller.textStyle.fontSize ??
                                                  14,
                                          onChanged: setTextFontSize),
                                    ),
                                  ],
                                ),

                                // Control text color hue
                                Row(
                                  children: [
                                    const Expanded(
                                        flex: 1, child: Text("Color")),
                                    Expanded(
                                      flex: 3,
                                      child: Slider.adaptive(
                                          min: 0,
                                          max: 359.99,
                                          value: HSVColor.fromColor(
                                                  controller.textStyle.color ??
                                                      red)
                                              .hue,
                                          activeColor:
                                              controller.textStyle.color,
                                          onChanged: setTextColor),
                                    ),
                                  ],
                                ),
                              ],
                              if (controller.shapeFactory != null) ...[
                                const Divider(),
                                const Text("Shape Settings"),

                                // Control text color hue
                                Row(
                                  children: [
                                    const Expanded(
                                        flex: 1, child: Text("Stroke Width")),
                                    Expanded(
                                      flex: 3,
                                      child: Slider.adaptive(
                                          min: 2,
                                          max: 25,
                                          value: controller
                                                  .shapePaint?.strokeWidth ??
                                              shapePaint.strokeWidth,
                                          onChanged: (value) =>
                                              setShapeFactoryPaint(
                                                  (controller.shapePaint ??
                                                          shapePaint)
                                                      .copyWith(
                                                strokeWidth: value,
                                              ))),
                                    ),
                                  ],
                                ),

                                Row(
                                  children: [
                                    const Expanded(
                                        flex: 1, child: Text("Color")),
                                    Expanded(
                                      flex: 3,
                                      child: Slider.adaptive(
                                          min: 0,
                                          max: 359.99,
                                          value: HSVColor.fromColor(
                                                  (controller.shapePaint ??
                                                          shapePaint)
                                                      .color)
                                              .hue,
                                          activeColor: (controller.shapePaint ??
                                                  shapePaint)
                                              .color,
                                          onChanged: (hue) =>
                                              setShapeFactoryPaint(
                                                  (controller.shapePaint ??
                                                          shapePaint)
                                                      .copyWith(
                                                color: HSVColor.fromAHSV(
                                                        1, hue, 1, 1)
                                                    .toColor(),
                                              ))),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, _, __) => Padding(
            padding: EdgeInsets.only(bottom: context.systemBottomInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    PhosphorIcons.scribbleLoop(),
                    color: controller.freeStyleMode == FreeStyleMode.draw
                        ? CustomColors.maroon
                        : null,
                  ),
                  onPressed: toggleFreeStyleDraw,
                ),
                ...<ShapeFactory, String>{
                  LineFactory(): "Line",
                  ArrowFactory(): "Arrow",
                  DoubleArrowFactory(): "Double Arrow",
                  RectangleFactory(): "Rectangle",
                  OvalFactory(): "Oval",
                }.entries.map((e) => IconButton(
                      color: selectedShape == e.value
                          ? CustomColors.maroon
                          : CustomColors.blue,
                      icon: Icon(
                        getShapeIcon(e.key),
                      ),
                      onPressed: () {
                        selectedShape = e.value;
                        selectedShapeFactory = e.key;
                        setState(() {});
                        if (controller.freeStyleMode == FreeStyleMode.draw) {
                          controller.freeStyleMode = FreeStyleMode.none;
                        }
                        selectShape(e.key);
                      },
                    )),
              ],
            ),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return buildDefault(context);
  }

  static PhosphorIconData getShapeIcon(ShapeFactory? shapeFactory) {
    if (shapeFactory is LineFactory) return PhosphorIcons.lineSegment();
    if (shapeFactory is ArrowFactory) return PhosphorIcons.arrowUpRight();
    if (shapeFactory is DoubleArrowFactory) {
      return PhosphorIcons.arrowsHorizontal();
    }
    if (shapeFactory is RectangleFactory) return PhosphorIcons.rectangle();
    if (shapeFactory is OvalFactory) return PhosphorIcons.circle();
    return PhosphorIcons.polygon();
  }

  void undo() {
    controller.undo();
  }

  void redo() {
    controller.redo();
  }

  void toggleFreeStyleDraw() {
    if (controller.shapeFactory != null) {
      selectedShape = null;
      selectedShapeFactory = null;
      controller.shapeFactory = null;
    }
    controller.freeStyleMode = controller.freeStyleMode != FreeStyleMode.draw
        ? FreeStyleMode.draw
        : FreeStyleMode.none;
  }

  void addText() {
    if (textFocusNode.hasFocus) {
      textFocusNode.unfocus();
      return;
    }
    if (controller.freeStyleMode != FreeStyleMode.none) {
      controller.freeStyleMode = FreeStyleMode.none;
    }
    if (controller.shapeFactory != null) {
      selectedShape = null;
      selectedShapeFactory = null;
      controller.shapeFactory = null;
    }
    controller.addText();
  }

  void setFreeStyleStrokeWidth(double value) {
    controller.freeStyleStrokeWidth = value;
  }

  void setFreeStyleColor(double hue) {
    controller.freeStyleColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  }

  void setTextFontSize(double size) {
    setState(() {
      controller.textSettings = controller.textSettings.copyWith(
          textStyle:
              controller.textSettings.textStyle.copyWith(fontSize: size));
    });
  }

  void setShapeFactoryPaint(Paint paint) {
    // Set state is just to update the current UI, the [FlutterPainter] UI updates without it
    setState(() {
      controller.shapePaint = paint;
    });
  }

  void setTextColor(double hue) {
    controller.textStyle = controller.textStyle
        .copyWith(color: HSVColor.fromAHSV(1, hue, 1, 1).toColor());
  }

  void selectShape(ShapeFactory? factory) {
    if (controller.freeStyleMode == FreeStyleMode.draw) {
      controller.freeStyleMode = FreeStyleMode.none;
    }
    controller.shapeFactory = factory;
  }
}
