import 'package:flutter/material.dart';
import 'package:image_editor_plus/data/image_item.dart';
import 'package:hand_signature/signature.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ImageDrawing extends StatefulWidget {
  final ImageItem image;

  const ImageDrawing({
    super.key,
    required this.image,
  });

  @override
  State<ImageDrawing> createState() => _ImageDrawingState();
}

class _ImageDrawingState extends State<ImageDrawing> {
  Color pickerColor = Colors.white;
  Color currentColor = Colors.white;

  final control = HandSignatureControl(
    threshold: 3.0,
    smoothRatio: 0.65,
    velocityRange: 2.0,
  );

  List<CubicPath> undoList = [];
  bool skipNextEvent = false;

  List<Color> colorList = [
    Colors.black,
    Colors.white,
    Colors.blue,
    Colors.green,
    Colors.pink,
    Colors.purple,
    Colors.brown,
    Colors.indigo,
  ];

  void changeColor(Color color) {
    currentColor = color;
    setState(() {});
  }

  @override
  void initState() {
    control.addListener(() {
      if (control.hasActivePath) return;

      if (skipNextEvent) {
        skipNextEvent = false;
        return;
      }

      undoList = [];
      setState(() {});
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.clear),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(
                Icons.undo,
                color: control.paths.isNotEmpty
                    ? Colors.white
                    : Colors.white.withAlpha(80),
              ),
              onPressed: () {
                if (control.paths.isEmpty) return;
                skipNextEvent = true;
                undoList.add(control.paths.last);
                control.stepBack();
                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(
                Icons.redo,
                color: undoList.isNotEmpty
                    ? Colors.white
                    : Colors.white.withAlpha(80),
              ),
              onPressed: () {
                if (undoList.isEmpty) return;

                control.paths.add(undoList.removeLast());
                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                if (control.paths.isEmpty) return Navigator.pop(context);

                // Generate image with original dimensions of the input image
                var data = await control.toImage(
                  color: currentColor,
                  height: widget.image.height,
                  width: widget.image.width,
                );

                if (!mounted) return;

                // Return the generated image data
                return Navigator.pop(context, data!.buffer.asUint8List());
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Display the image with full container size
                  Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: Image.memory(widget.image.image).image,
                        fit: BoxFit.fill, // Ensure it fits within the bounds
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: HandSignature(
                      control: control,
                      color: currentColor,
                      width: 1.0, // Minimum width of the drawing line (adjustable)
                      maxWidth: 3.0, // Maximum width of the drawing line (adjustable)
                      type: SignatureDrawType.shape, // Shape-based drawing type
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(blurRadius: 2),
              ],
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                ColorButton(
                  color: Colors.yellow,
                  onTap: (color) {
                    showModalBottomSheet(
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.only(topRight: Radius.circular(10), topLeft: Radius.circular(10)),
                      ),
                      context: context,
                      builder: (context) {
                        return Container(
                          color: Colors.black87,
                          padding:
                              const EdgeInsets.all(20), // Padding for content
                          child:
                              SingleChildScrollView(child:
                                  HueRingPicker(pickerColor:
                                      pickerColor, onColorChanged:
                                      changeColor)),
                        );
                      },
                    );
                  },
                ),
                for (int i = 0; i < colorList.length; i++)
                  ColorButton(
                    color:
                        colorList[i],
                    onTap:
                        (color) => changeColor(color),
                    isSelected:
                        colorList[i] == currentColor, // Highlight selected color
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Button used in bottomNavigationBar in ImageDrawing
class ColorButton extends StatelessWidget {
  final Color color;
  final Function onTap;
  final bool isSelected;

  const ColorButton({
    super.key,
    required this.color,
    required this.onTap,
    this.isSelected = false, // Default to not selected
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () { onTap(color); }, // Trigger onTap function when pressed
      child:
          Container(height:
              34, width:
              34, margin:
              const EdgeInsets.symmetric(horizontal:
                  10, vertical:
                  23), decoration:
                  BoxDecoration(color:
                      color, borderRadius:
                      BorderRadius.circular(16), border:
                      Border.all(color:
                          isSelected ? Colors.white : Colors.white54, width:
                          isSelected ? 3 : 1))),
    );
  }
}
