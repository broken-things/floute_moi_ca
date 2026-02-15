# Floutage 2 plaque — Anonymiseur de Plaques

**Floutage 2 plaque** est une application Flutter conçue pour répondre à une problématique personnelle : flouter les plaques d'immatriculation efficacement tout en garantissant la confidentialité des données.


## Points Forts

* **Traitement de l'image en local :** Aucune image n'est envoyée sur le cloud. Tout se passe sur le processeur du téléphone (respect total de la vie privée).
* **Performance Multithread :** Utilise les *Isolates* de Dart (via `compute`) pour traiter les fichiers lourds en arrière-plan sans geler l'interface utilisateur.
* **Haute Fidélité :** Conserve le format d'origine (JPG, PNG) et la résolution initiale.
* **Interface Intuitive** 



## Stack Technique

* **Framework :** Flutter
* **IA / Machine Learning :** `google_mlkit_text_recognition` (OCR On-device)
* **Moteur d'Image :** `image` (Traitement des pixels et flou Gaussien)
* **Gestion de Fichiers :** `path_provider` & `gal` (Sauvegarde en galerie publique)
* **Compilation :** Gradle (Kotlin DSL) avec règles R8/ProGuard.

## Fonctionnement Technique

* **Acquisition & Normalisation :** L'image est chargée avec une limite de 10000px pour corriger les éventuels marqueurs JPEG corrompus (ex: error d7).
* **Scan OCR :** L'IA repère tous les blocs de texte présents.
* **Filtre de Ratio :** L'algorithme filtre les détections pour ne garder que les rectangles dont le ratio $Largeur > Hauteur \times 1.5$ (format standard d'une plaque).
* **Flou Gaussien :** Un flou avec un rayon de 40 pixels est appliqué sur la zone découpée.
* **Encodage :** L'image est ré-encodée en qualité 100% (JPG ou PNG selon la source).