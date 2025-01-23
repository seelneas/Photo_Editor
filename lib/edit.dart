import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_editor_plus/data/image_item.dart';
import 'package:image_editor_plus/data/layer.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_editor_plus/layers/background_blur_layer.dart';
import 'package:image_editor_plus/layers/background_layer.dart';
import 'package:image_editor_plus/layers/emoji_layer.dart';
import 'package:image_editor_plus/layers/image_layer.dart';
import 'package:image_editor_plus/layers/text_layer.dart';
import 'package:image_editor_plus/loading_screen.dart';
import 'package:image_editor_plus/modules/all_emojies.dart';
import 'package:image_editor_plus/modules/colors_picker.dart';
import 'package:image_editor_plus/modules/text.dart';
import 'package:image_editor_plus/utils.dart';
import 'package:photo_editor/drawing.dart';
import 'package:screenshot/screenshot.dart';



List<Layer> layers = [], undoLayers = [], removedLayers = [];
Map<String, String> _translations = {};

String i18n(String sourceString) =>
    _translations[sourceString.toLowerCase()] ?? sourceString;

class EditImageScreen extends StatelessWidget {
  final dynamic image;
  final Directory? savePath;
  final ImageEditorFeatures features;
  final List<AspectRatioOption> cropAvailableRatios;

  const EditImageScreen({
    Key? key,
    this.image,
    this.savePath,
    this.features = const ImageEditorFeatures(
      pickFromGallery: false,
      captureFromCamera: false,
      crop: true,
      blur: true,
      brush: true,
      emoji: true,
      filters: true,
      flip: true,
      rotate: true,
      text: true,
    ),
    this.cropAvailableRatios = const [
      AspectRatioOption(title: 'Freeform'),
      AspectRatioOption(title: '1:1', ratio: 1),
      AspectRatioOption(title: '4:3', ratio: 4 / 3),
      AspectRatioOption(title: '5:4', ratio: 5 / 4),
      AspectRatioOption(title: '7:5', ratio: 7 / 5),
      AspectRatioOption(title: '16:9', ratio: 16 / 9),
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleImageEditorNoGalleryCamera(
      image: image,
      savePath: savePath,
      features: features,
      cropAvailableRatios: cropAvailableRatios,
    );
  }
}
class SingleImageEditorNoGalleryCamera extends StatefulWidget {
  final Directory? savePath;
  final dynamic image;
  final ImageEditorFeatures features;
  final List<AspectRatioOption> cropAvailableRatios;

  const SingleImageEditorNoGalleryCamera({
    super.key,
    this.savePath,
    this.image,
    this.features = const ImageEditorFeatures(
      pickFromGallery: false,
      captureFromCamera: false,
      crop: true,
      blur: true,
      brush: true,
      emoji: true,
      filters: true,
      flip: true,
      rotate: true,
      text: true,
    ),
    this.cropAvailableRatios = const [
      AspectRatioOption(title: 'Freeform'),
      AspectRatioOption(title: '1:1', ratio: 1),
      AspectRatioOption(title: '4:3', ratio: 4 / 3),
      AspectRatioOption(title: '5:4', ratio: 5 / 4),
      AspectRatioOption(title: '7:5', ratio: 7 / 5),
      AspectRatioOption(title: '16:9', ratio: 16 / 9),
    ],
  });

  @override
  createState() => _SingleImageEditorNoGalleryCameraState();
}

class _SingleImageEditorNoGalleryCameraState extends State<SingleImageEditorNoGalleryCamera> {
  ImageItem currentImage = ImageItem();

  Offset offset1 = Offset.zero;
  Offset offset2 = Offset.zero;
  final scaffoldGlobalKey = GlobalKey<ScaffoldState>();

  final GlobalKey container = GlobalKey();
  final GlobalKey globalKey = GlobalKey();
  ScreenshotController screenshotController = ScreenshotController();

  @override
  void dispose() {
    layers.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadImage(widget.image!);
      });
    }
  }

//Filter Actions
  List<Widget> get filterActions {
    return [
      const BackButton(),
      SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(children: [

            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.undo,
                  color: layers.length > 1 || removedLayers.isNotEmpty
                      ? Colors.white
                      : Colors.grey),
              onPressed: () {
                if (removedLayers.isNotEmpty) {
                  layers.add(removedLayers.removeLast());
                  setState(() {});
                  return;
                }

                if (layers.length <= 1) return; 

                undoLayers.add(layers.removeLast());

                setState(() {});
              },
            ),

            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.redo,
                  color: undoLayers.isNotEmpty ? Colors.white : Colors.grey),
              onPressed: () {
                if (undoLayers.isEmpty) return;

                layers.add(undoLayers.removeLast());

                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                resetTransformation();
                setState(() {});

                LoadingScreen(scaffoldGlobalKey).show();

                var binaryIntList =
                    await screenshotController.capture(pixelRatio: pixelRatio);

                LoadingScreen(scaffoldGlobalKey).hide();

                if (mounted) Navigator.pop(context, binaryIntList);
              },
            ),
          ]),
        ),
      ),
    ];
  }

Future<void> loadImage(dynamic imageFile) async {
        if (imageFile == null) throw Exception("Invalid image file.");
        await currentImage.load(imageFile);
        layers.clear();
        layers.add(BackgroundLayerData(file: currentImage));
        if (mounted) setState(() {});  
}


  double flipValue = 0;
  int rotateValue = 0;

  double x = 0;
  double y = 0;

  double lastScaleFactor = 1, scaleFactor = 1;
  double widthRatio = 1, heightRatio = 1, pixelRatio = 1;

  resetTransformation() {
    scaleFactor = 1;
    x = 0;
    y = 0;
    setState(() {});
  }

  /// obtain image Uint8List by merging layers
  Future<Uint8List?> getMergedImage() async {
    if (layers.length == 1 && layers.first is BackgroundLayerData) {
      return (layers.first as BackgroundLayerData).file.image;
    } else if (layers.length == 1 && layers.first is ImageLayerData) {
      return (layers.first as ImageLayerData).image.image;
    }

    return screenshotController.capture(
      pixelRatio: pixelRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;

    var layersStack = Stack(
      children: layers.map((layerItem) {
        // Background layer
        if (layerItem is BackgroundLayerData) {
          return BackgroundLayer(
            layerData: layerItem,
            onUpdate: () {
              setState(() {});
            },
          );
        }

        // Image layer
        if (layerItem is ImageLayerData) {
          return ImageLayer(
            layerData: layerItem,
            onUpdate: () {
              setState(() {});
            },
          );
        }

        // Background blur layer
        if (layerItem is BackgroundBlurLayerData && layerItem.radius > 0) {
          return BackgroundBlurLayer(
            layerData: layerItem,
            onUpdate: () {
              setState(() {});
            },
          );
        }

        // Emoji layer
        if (layerItem is EmojiLayerData) {
          return EmojiLayer(
            layerData: layerItem,
            onUpdate: () {
              setState(() {});
            },
          );
        }

        // Text layer
        if (layerItem is TextLayerData) {
          return TextLayer(
            layerData: layerItem,
            onUpdate: () {
              setState(() {});
            },
          );
        }

        // Blank layer
        return Container();
      }).toList(),
    );

    widthRatio = currentImage.width / viewportSize.width;
    heightRatio = currentImage.height / viewportSize.height;
    pixelRatio = math.max(heightRatio, widthRatio);

    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        key: scaffoldGlobalKey,
        body: Stack(children: [
          GestureDetector(
            onScaleUpdate: (details) {

              // move
              if (details.pointerCount == 1) {
                x += details.focalPointDelta.dx;
                y += details.focalPointDelta.dy;
                setState(() {});
              }

              // scale
              if (details.pointerCount == 2) {
                // print([details.horizontalScale, details.verticalScale]);
                if (details.horizontalScale != 1) {
                  scaleFactor = lastScaleFactor *
                      math.min(details.horizontalScale, details.verticalScale);
                  setState(() {});
                }
              }
            },
            onScaleEnd: (details) {
              lastScaleFactor = scaleFactor;
            },

            child: Center(
              child: SizedBox(
                height: currentImage.height / pixelRatio,
                width: currentImage.width / pixelRatio,
                child: Screenshot(
                  controller: screenshotController,
                  child: RotatedBox(
                    quarterTurns: rotateValue,
                    child: Transform(
                      transform: Matrix4(
                      1, 0, 0, 0,
                      0, 1, 0, 0,
                      0, 0, 1, 0,
                      x, y, 0, 1 / scaleFactor,
                      )..rotateY(flipValue),
                      alignment: FractionalOffset.center,
                      child: layersStack,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                ),
                child: Row(
                  children: filterActions,
                ),
              ),
            ),
          )
        ]),

        bottomNavigationBar: SafeArea(
          child: Container(
            alignment: Alignment.bottomCenter,
            height: 94 + MediaQuery.of(context).padding.bottom,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.rectangle,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
          
                    // Crop button
                    if (widget.features.crop)                  
                      BottomButton(
                        icon: Icons.crop,
                        text: i18n('Crop'),
                        onTap: () async {
                          resetTransformation(); // Any transformation like scale and position
                          LoadingScreen(scaffoldGlobalKey).show();
          
                          var mergedImage = await getMergedImage();
          
                          LoadingScreen(scaffoldGlobalKey).hide();
          
                          if (!mounted) return;
          
                          Uint8List? croppedImage = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageCropper(
                                image: mergedImage!,
                                availableRatios: widget.cropAvailableRatios,
                              ),
                            ),
                          );
          
                          if (croppedImage == null) return;
          
                          flipValue = 0;
                          rotateValue = 0;
          
                          await currentImage.load(croppedImage);
                          setState(() {});
                        },
                      ),
          
          
                    // Brush Button
                    if (widget.features.brush)
                      BottomButton(
                        icon: Icons.edit,
                        text: i18n('Brush'),
                        onTap: () async {
                          var drawing = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageDrawing(
                                image: currentImage,
                              ),
                            ),
                          );
          
                          if (drawing != null) {
                            undoLayers.clear();
                            removedLayers.clear();
                            layers.add(
                              ImageLayerData(
                                image: ImageItem(drawing),
                              ),
                            );
                            setState(() {});
                          }
                        },
                      ),
          
                    
                    // Text Button
                    if (widget.features.text)
                      BottomButton(
                        icon: Icons.text_fields,
                        text: i18n('Text'),
                        onTap: () async {
                          TextLayerData? layer = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TextEditorImage(),
                            ),
                          );
          
                          if (layer == null) return;
          
                          undoLayers.clear();
                          removedLayers.clear();
          
                          layers.add(layer);
          
                          setState(() {});
                        },
                      ),
          
          
                    //Flip Button
                    if (widget.features.flip)
                      BottomButton(
                        icon: Icons.flip,
                        text: i18n('Flip'),
                        onTap: () {
                          setState(() {
                            flipValue = flipValue == 0 ? math.pi : 0;
                          });
                        },
                      ),
          
                    //Rotate Left Button
                    if (widget.features.rotate)
                      BottomButton(
                        icon: Icons.rotate_left,
                        text: i18n('Rotate left'),
                        onTap: () {
                          var t = currentImage.width;
                          currentImage.width = currentImage.height;
                          currentImage.height = t;
          
                          rotateValue--;
                          setState(() {});
                        },
                      ),
          
                    //Rotate Right Button 
                    if (widget.features.rotate)
                      BottomButton(
                        icon: Icons.rotate_right,
                        text: i18n('Rotate right'),
                        onTap: () {
                          var t = currentImage.width;
                          currentImage.width = currentImage.height;
                          currentImage.height = t;
          
                          rotateValue++;
                          setState(() {});
                        },
                      ),
           
                    //Blur Button
                    if (widget.features.blur)
                      BottomButton(
                        icon: Icons.blur_on,
                        text: i18n('Blur'),
                        onTap: () {
                          var blurLayer = BackgroundBlurLayerData(
                            color: Colors.transparent,
                            radius: 0.0,
                            opacity: 0.0,
                          );
          
                          undoLayers.clear();
                          removedLayers.clear();
                          layers.add(blurLayer);
                          setState(() {});
          
                          showModalBottomSheet(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  topLeft: Radius.circular(10)),
                            ),
                            context: context,
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (context, setS) {
                                  return SingleChildScrollView(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(10),
                                            topLeft: Radius.circular(10)),
                                      ),
                                      padding: const EdgeInsets.all(20),
                                      height: 400,
                                      child: Column(
                                        children: [
                                          Center(
                                              child: Text(
                                            i18n('Slider Filter Color')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          )),
                                          const Divider(),
                                          const SizedBox(height: 20.0),
                                          Text(
                                            i18n('Slider Color'),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(children: [
                                            Expanded(
                                              child: BarColorPicker(
                                                width: 300,
                                                thumbColor: Colors.white,
                                                cornerRadius: 10,
                                                pickMode: PickMode.color,
                                                colorListener: (int value) {
                                                  setS(() {
                                                    setState(() {
                                                      blurLayer.color =
                                                          Color(value);
                                                    });
                                                  });
                                                },
                                              ),
                                            ),
                                          ]),
                                          const SizedBox(height: 5.0),
                                          Text(
                                            i18n('Blur Radius'),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 10.0),
                                          Row(children: [
                                            Expanded(
                                              child: Slider(
                                                activeColor: Colors.white,
                                                inactiveColor: Colors.grey,
                                                value: blurLayer.radius,
                                                min: 0.0,
                                                max: 10.0,
                                                onChanged: (v) {
                                                  setS(() {
                                                    setState(() {
                                                      blurLayer.radius = v;
                                                    });
                                                  });
                                                },
                                              ),
                                            ),
                                            TextButton(
                                              child: Text(
                                                i18n('Reset'),
                                              ),
                                              onPressed: () {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.radius = 0.0;
                                                  });
                                                });
                                              },
                                            )
                                          ]),
                                          const SizedBox(height: 5.0),
                                          Text(
                                            i18n('Color Opacity'),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 10.0),
                                          Row(children: [
                                            Expanded(
                                              child: Slider(
                                                activeColor: Colors.white,
                                                inactiveColor: Colors.grey,
                                                value: blurLayer.opacity,
                                                min: 0.00,
                                                max: 1.0,
                                                onChanged: (v) {
                                                  setS(() {
                                                    setState(() {
                                                      blurLayer.opacity = v;
                                                    });
                                                  });
                                                },
                                              ),
                                            ),
                                            TextButton(
                                              child: Text(
                                                i18n('Reset'),
                                              ),
                                              onPressed: () {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.opacity = 0.0;
                                                  });
                                                });
                                              },
                                            )
                                          ]),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
          
          
                   
          
                    //Filter Button
                    if (widget.features.filters)
                      BottomButton(
                        icon: Icons.photo,
                        text: i18n('Filter'),
                        onTap: () async {
                          resetTransformation();
          
                          var mergedImage = await getMergedImage();
          
                          if (!mounted) return;
          
                          Uint8List? filterAppliedImage = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageFilters(
                                image: mergedImage!,
                              ),
                            ),
                          );
          
                          if (filterAppliedImage == null) return;
          
                          removedLayers.clear();
                          undoLayers.clear();
          
                          var layer = BackgroundLayerData(
                            file: ImageItem(filterAppliedImage),
                          );
          
                          layers.add(layer);
          
                          await layer.file.status;
          
                          setState(() {});
                        },
                      ),
          
          
                    //Emoji Button
                    if (widget.features.emoji)
                      BottomButton(
                        icon: FontAwesomeIcons.faceSmile,
                        text: i18n('Emoji'),
                        onTap: () async {
                          EmojiLayerData? layer = await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.black,
                            builder: (BuildContext context) {
                              return const Emojies();
                            },
                          );
          
                          if (layer == null) return;
          
                          undoLayers.clear();
                          removedLayers.clear();
                          layers.add(layer);
          
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}