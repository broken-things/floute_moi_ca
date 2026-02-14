import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  File? _displayImage; // L'image finale à afficher
  bool _isProcessing = false; // État du chargement
  final ImagePicker _picker = ImagePicker();

  // Instance du moteur de reconnaissance de texte (Latin pour l'Europe/USA)
  late TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Fonction principale : Sélectionne, Analyse et Floute l'image
  Future<void> _pickAndProcessImage() async {
    // 1. Sélection de l'image
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 10000,
      maxHeight: 10000,
      imageQuality: 100,
    );

    if (pickedFile == null) return;

    setState(() => _isProcessing = true);

    // Préparation de l'image pour l'IA
    final inputImage = InputImage.fromFilePath(pickedFile.path);

    // Détection des blocs de texte
    final recognizedText = await _textRecognizer.processImage(inputImage);

    // Chargement des données "img.Image" pour modification
    final bytes = await pickedFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage != null) {
      // Parcours des zones de texte détectées
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          final rect = line.boundingBox;

          // Filtre de sécurité : floutage des formes similaires aux plaques
          // Ratio Largeur / Hauteur > 1.2
          if (rect.width > rect.height * 1.2) {
            // Calcul des coordonnées sécurisées (ne pas sortir de l'image)
            int x = rect.left.toInt().clamp(0, originalImage.width);
            int y = rect.top.toInt().clamp(0, originalImage.height);
            int w = rect.width.toInt().clamp(0, originalImage.width - x);
            int h = rect.height.toInt().clamp(0, originalImage.height - y);

            if (w > 0 && h > 0) {
              // Découpe la zone de la plaque
              img.Image part = img.copyCrop(
                originalImage,
                x: x,
                y: y,
                width: w,
                height: h,
              );

              // Applique le flou Gaussien (puissance 40 pour la HD)
              img.Image blurredPart = img.gaussianBlur(part, radius: 40);

              // Fusionne la zone floutée sur l'image d'origine
              img.compositeImage(originalImage, blurredPart, dstX: x, dstY: y);
            }
          }
        }
      }

      // Encodage final
      String extension = p.extension(pickedFile.path).toLowerCase();
      Uint8List encodedBytes;

      if (extension == '.png') {
        encodedBytes = Uint8List.fromList(img.encodePng(originalImage));
      } else {
        // Par défaut en JPG qualité maximale pour le reste
        encodedBytes = Uint8List.fromList(
          img.encodeJpg(originalImage, quality: 100),
        );
      }

      // Enregistrement dans un fichier temporaire pour l'aperçu UI
      final tempDir = await getTemporaryDirectory();
      final blurredFile = File('${tempDir.path}/resultat$extension');
      await blurredFile.writeAsBytes(encodedBytes);

      setState(() {
        _displayImage = blurredFile;
        _isProcessing = false;
      });
    }
  }

  /// Sauvegarde l'image traitée dans la galerie photo du téléphone
  Future<void> _saveToGallery() async {
    if (_displayImage == null) return;
    try {
      await Gal.putImage(_displayImage!.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sauvegardé !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur de sauvegarde"),
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
          'Floute moi ça',
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
                  SizedBox(height: 15),
                  Text("Analyse en cours..."),
                ],
              )
            : _displayImage == null
            ? _buildUploadUI()
            : _buildResultUI(),
      ),
    );
  }

  // --- COMPOSANTS INTERFACE (UI) ---

  // Écran d'accueil avec bouton d'importation
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              size: 80,
              color: Colors.blueAccent,
            ),
            SizedBox(height: 20),
            Text(
              "Importer une photo",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Traitement local & sécurisé",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Écran de résultat avec affichage et boutons d'actions
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
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
                label: const Text("Nouveau floutage"),
              ),
              ElevatedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.download_done_rounded),
                label: const Text("Enregistrer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
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
    _textRecognizer.close(); // Libère la mémoire de l'IA à la fermeture
    super.dispose();
  }
}
