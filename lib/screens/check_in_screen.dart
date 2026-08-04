import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final storeController = TextEditingController();
  final notesController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  XFile? capturedPhoto;
  Position? capturedPosition;
  bool isSubmitting = false;

  Future<void> takePhoto() async {
    try {
      final photo = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );

      if (photo == null || !mounted) return;

      setState(() {
        capturedPhoto = photo;
      });
    } catch (error) {
      if (!mounted) return;
      showMessage('Unable to take photo: $error');
    }
  }

  Future<void> captureLocation() async {
    try {
      final locationEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!locationEnabled) {
        showMessage(
          'Location services are disabled. Please turn on GPS.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission is permanently denied. '
          'Please enable it in phone settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        capturedPosition = position;
      });
    } catch (error) {
      if (!mounted) return;
      showMessage('Unable to capture location: $error');
    }
  }

  Future<void> submitVisit() async {
    final storeName = storeController.text.trim();
    final notes = notesController.text.trim();

    if (storeName.isEmpty) {
      showMessage('Please enter the store name.');
      return;
    }

    if (capturedPhoto == null) {
      showMessage('Please take a photo first.');
      return;
    }

    if (capturedPosition == null) {
      showMessage('Please capture your location first.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage(
        'Your login session has expired. Please log in again.',
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await Supabase.instance.client.from('visits').insert({
        'salesperson_id': user.id,
        'store_name': storeName,
        'latitude': capturedPosition!.latitude,
        'longitude': capturedPosition!.longitude,
        'accuracy_meters': capturedPosition!.accuracy,

        // Photo upload will be added next.
        'photo_path': null,

        'notes': notes.isEmpty ? null : notes,
        'visited_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit submitted successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      showMessage('Database error: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to submit visit: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    storeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: storeController,
              enabled: !isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Store name',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: isSubmitting ? null : takePhoto,
              icon: Icon(
                capturedPhoto != null
                    ? Icons.check_circle
                    : Icons.camera_alt_outlined,
              ),
              label: Text(
                capturedPhoto != null
                    ? 'PHOTO READY'
                    : 'TAKE PHOTO',
              ),
            ),

            if (capturedPhoto != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(capturedPhoto!.path),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed:
                  isSubmitting ? null : captureLocation,
              icon: Icon(
                capturedPosition != null
                    ? Icons.check_circle
                    : Icons.my_location,
              ),
              label: Text(
                capturedPosition != null
                    ? 'LOCATION CAPTURED'
                    : 'CAPTURE LOCATION',
              ),
            ),

            if (capturedPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Accuracy: '
                '${capturedPosition!.accuracy.toStringAsFixed(1)} m',
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            TextField(
              controller: notesController,
              enabled: !isSubmitting,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed:
                    isSubmitting ? null : submitVisit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SUBMIT VISIT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}