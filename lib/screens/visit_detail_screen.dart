import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({
    super.key,
    required this.visit,
  });

  final Map<String, dynamic> visit;

  @override
  State<VisitDetailScreen> createState() =>
      _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  String? signedPhotoUrl;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    loadPhoto();
  }

  Future<void> loadPhoto() async {
    final photoPath = widget.visit['photo_path'] as String?;

    if (photoPath == null || photoPath.isEmpty) {
      return;
    }

    setState(() {
      isLoadingPhoto = true;
    });

    try {
      final url = await Supabase.instance.client.storage
          .from('visit-photos')
          .createSignedUrl(
            photoPath,
            3600,
          );

      if (!mounted) return;

      setState(() {
        signedPhotoUrl = url;
        isLoadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load photo: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;

    final profile =
        visit['profiles'] as Map<String, dynamic>?;

    final salespersonName =
        profile?['full_name']?.toString() ?? 'Unknown salesperson';

    final visitTime = DateTime.parse(
      visit['visited_at'] as String,
    ).toLocal();

    final latitude = visit['latitude'];
    final longitude = visit['longitude'];
    final accuracy = visit['accuracy_meters'];
    final notes = visit['notes']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isLoadingPhoto)
            const SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (signedPhotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                signedPhotoUrl!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: Text('Unable to display photo'),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: const Text('No photo available'),
            ),

          const SizedBox(height: 24),

          Text(
            visit['store_name']?.toString() ?? 'Unknown store',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 24),

          _DetailRow(
            icon: Icons.person_outline,
            label: 'Salesperson',
            value: salespersonName,
          ),

          _DetailRow(
            icon: Icons.access_time,
            label: 'Visit time',
            value:
                '${visitTime.day}/${visitTime.month}/${visitTime.year} '
                '${visitTime.hour.toString().padLeft(2, '0')}:'
                '${visitTime.minute.toString().padLeft(2, '0')}',
          ),

          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Latitude',
            value: latitude?.toString() ?? '-',
          ),

          _DetailRow(
            icon: Icons.location_on,
            label: 'Longitude',
            value: longitude?.toString() ?? '-',
          ),

          _DetailRow(
            icon: Icons.gps_fixed,
            label: 'GPS accuracy',
            value: accuracy == null
                ? '-'
                : '${accuracy.toString()} metres',
          ),

          const SizedBox(height: 16),

          Text(
            'Notes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          Text(
            notes == null || notes.isEmpty
                ? 'No notes provided.'
                : notes,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}