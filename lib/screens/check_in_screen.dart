import 'package:flutter/material.dart';

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

  void submitVisit() {
    final storeName = storeController.text.trim();

    if (storeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the store name.'),
        ),
      );
      return;
    }

    if (!photoCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo first.'),
        ),
      );
      return;
    }

    if (!locationCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your location first.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Form looks good. Real submission comes next.',
        ),
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
              decoration: const InputDecoration(
                labelText: 'Store name',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: simulatePhoto,
              icon: Icon(
                photoCaptured
                    ? Icons.check_circle
                    : Icons.camera_alt_outlined,
              ),
              label: Text(
                photoCaptured
                    ? 'PHOTO READY'
                    : 'TAKE PHOTO',
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: simulateLocation,
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
                onPressed: submitVisit,
                child: const Text(
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