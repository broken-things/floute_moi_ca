import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlateBlurrerApp(),
    ),
  );
}

class PlateBlurrerApp extends StatefulWidget {
  const PlateBlurrerApp({super.key});

  @override
  State<PlateBlurrerApp> createState() => _PlateBlurrerAppState();
}

class _PlateBlurrerAppState extends State<PlateBlurrerApp> {
  File? _displayImage;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();
  late ObjectDetector _objectDetector;

  @override
  void initState() {
    super.initState();
    // Initialisation de la détection d'objets (Local)
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  // Fonction pour traiter l'image
  Future<void> _pickAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    // Détection des plaques (ML Kit)
    final inputImage = InputImage.fromFilePath(pickedFile.path);
    final List<DetectedObject> objects = await _objectDetector.processImage(
      inputImage,
    );

    // Chargement des pixels
    final bytes = await pickedFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage != null) {
      // Application du flou sur chaque zone contenant la plaque
      for (var obj in objects) {
        final rect = obj.boundingBox;

        int x = rect.left.toInt().clamp(0, originalImage.width);
        int y = rect.top.toInt().clamp(0, originalImage.height);
        int w = rect.width.toInt().clamp(0, originalImage.width - x);
        int h = rect.height.toInt().clamp(0, originalImage.height - y);

        if (w > 0 && h > 0) {
          img.Image part = img.copyCrop(
            originalImage,
            x: x,
            y: y,
            width: w,
            height: h,
          );
          img.Image blurredPart = img.gaussianBlur(part, radius: 25);
          img.compositeImage(originalImage, blurredPart, dstX: x, dstY: y);
        }
      }

      // Conservation du format d'origine
      String extension = p.extension(pickedFile.path).toLowerCase();
      Uint8List encodedBytes;

      if (extension == '.png') {
        encodedBytes = Uint8List.fromList(img.encodePng(originalImage));
      } else if (extension == '.jpg' || extension == '.jpeg') {
        encodedBytes = Uint8List.fromList(
          img.encodeJpg(originalImage, quality: 100),
        );
      } else {
        // Pour les autres formats (RAW, etc.), on exporte en PNG haute qualité
        extension = '.png';
        encodedBytes = Uint8List.fromList(img.encodePng(originalImage));
      }

      // 5. Sauvegarde temporaire pour l'affichage
      final tempDir = await getTemporaryDirectory();
      final blurredFile = File('${tempDir.path}/resultat$extension');
      await blurredFile.writeAsBytes(encodedBytes);

      setState(() {
        _displayImage = blurredFile;
        _isProcessing = false;
      });
    }
  }

  // Sauvegarde finale dans la galerie publique du téléphone
  Future<void> _saveToGallery() async {
    if (_displayImage == null) return;

    try {
      await Gal.putImage(_displayImage!.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Image enregistrée dans la galerie !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'enregistrement"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Floute moi ç',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Analyse locale en cours..."),
                ],
              )
            : _displayImage == null
            ? _buildUploadUI()
            : _buildResultUI(),
      ),
    );
  }

  Widget _buildUploadUI() {
    return GestureDetector(
      onTap: _pickAndProcessImage,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              "Cliquez pour choisir une photo",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              "Traitement 100% privé et local",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUI() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(_displayImage!),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _pickAndProcessImage,
                icon: const Icon(Icons.refresh),
                label: const Text("Autre photo"),
              ),
              ElevatedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.download),
                label: const Text("Enregistrer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _objectDetector.close();
    super.dispose();
  }
}
