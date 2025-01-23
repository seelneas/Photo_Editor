import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'editing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();

      // Navigate to the editing screen
      if (mounted) { // Ensure the widget is still in the widget tree
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditingScreen(imageData: bytes),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset("assets/images/wallpaper.png"
            ,fit: BoxFit.fitHeight,),
          ),
          Column(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    'Photo Editor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      wordSpacing: 7,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                         onPressed: () => pickImage(ImageSource.gallery),
                         child: const Text('Gallery'),
                          ),
                      
                       ElevatedButton(
                        onPressed: () => pickImage(ImageSource.camera),
                        child: const Text('Camera'),
                        ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
} 