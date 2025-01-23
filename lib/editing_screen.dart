import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_editor/edit.dart'; 

class EditingScreen extends StatefulWidget {
  final Uint8List imageData;

  const EditingScreen({super.key, required this.imageData});

  @override
  State<EditingScreen> createState() => _EditingScreenState();
}

class _EditingScreenState extends State<EditingScreen> {
  late Uint8List imageData;
  late Uint8List originalImageData;  // Backup of the original image

  @override
  void initState() {
    super.initState();
    imageData = widget.imageData;
    originalImageData = widget.imageData;  // Store the original image data
  }

Future<void> saveImage(Uint8List editedImage, BuildContext context) async {
  final result = await ImageGallerySaver.saveImage(editedImage, quality: 100);
  if (result['isSuccess']) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image saved to gallery!')),
    );
  } else {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save image!')),
    );
  }
}


  Future<void> _showSaveDialog(Uint8List editedImage) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Do you want to save the edited image to the gallery or discard the changes?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('discard'); // User chooses to discard
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop('save'); // User chooses to save
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == 'save') {
      // ignore: use_build_context_synchronously
      await saveImage(editedImage, context);
    } else if (action == 'discard') {
      // Reset the image to its original state when discarding
      setState(() {
        imageData = originalImageData;  // Reset to the original image
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.memory(imageData),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final editedImage = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => EditImageScreen(image: imageData),
                ),
              );

              if (editedImage != null) {
                setState(() {
                  imageData = editedImage;
                });

                // Show save or discard dialog after editing
                await _showSaveDialog(editedImage);
              }
            },
            child: const Text('Edit Image'),
          ),
        ],
      ),
    );
  }
}  