import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final storeController = TextEditingController();
  final notesController = TextEditingController();

  bool photoCaptured = false;
  bool locationCaptured = false;
  bool isSubmitting = false;

  void simulatePhoto() {
    setState(() {
      photoCaptured = true;
    });
  }

  void simulateLocation() {
    setState(() {
      locationCaptured = true;
    });
  }

  Future<void> submitVisit() async {
    final storeName = storeController.text.trim();
    final notes = notesController.text.trim();

    if (storeName.isEmpty) {
      showMessage('Please enter the store name.');
      return;
    }

    if (!photoCaptured) {
      showMessage('Please take a photo first.');
      return;
    }

    if (!locationCaptured) {
      showMessage('Please capture your location first.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage('Your login session has expired. Please log in again.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await Supabase.instance.client.from('visits').insert({
        'salesperson_id': user.id,
        'store_name': storeName,

        // Temporary development values.
        // These will be replaced with real phone GPS later.
        'latitude': 0.0,
        'longitude': 0.0,
        'accuracy_meters': null,

        // Photo upload will be added when testing on the S10.
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
              onPressed: isSubmitting ? null : simulatePhoto,
              icon: Icon(
                photoCaptured
                    ? Icons.check_circle
                    : Icons.camera_alt_outlined,
              ),
              label: Text(
                photoCaptured ? 'PHOTO READY' : 'TAKE PHOTO',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : simulateLocation,
              icon: Icon(
                locationCaptured
                    ? Icons.check_circle
                    : Icons.my_location,
              ),
              label: Text(
                locationCaptured
                    ? 'LOCATION CAPTURED'
                    : 'CAPTURE LOCATION',
              ),
            ),
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
                onPressed: isSubmitting ? null : submitVisit,
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