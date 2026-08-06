import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_history_screen.dart';

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({
    super.key,
    required this.visit,
  });

  final Map<String, dynamic> visit;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final Geocoding geocoding = Geocoding();
  
  String? signedPhotoUrl;
  String? readableAddress;

  bool isLoadingPhoto = false;
  bool isLoadingAddress = false;

    @override
  void initState() {
    super.initState();
    loadPhoto();
    loadAddress();
  }

  Future<void> loadPhoto() async {
    final photoPath = widget.visit['photo_path']?.toString();

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

      showMessage('Unable to load photo: $error');
    }
  }

  Future<void> loadAddress() async {
    final latitude =
        (widget.visit['latitude'] as num?)?.toDouble();

    final longitude =
        (widget.visit['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      setState(() {
        readableAddress = 'Location unavailable';
      });
      return;
    }

    setState(() {
      isLoadingAddress = true;
    });

    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        setState(() {
          readableAddress = 'Address unavailable';
          isLoadingAddress = false;
        });
        return;
      }

      final place = placemarks.first;
      final addressParts = <String>[];

      void addAddressPart(String? value) {
        final cleanedValue = value?.trim();

        if (cleanedValue != null &&
            cleanedValue.isNotEmpty &&
            !addressParts.contains(cleanedValue)) {
          addressParts.add(cleanedValue);
        }
      }

      addAddressPart(place.street);
      addAddressPart(place.subLocality);
          

      setState(() {
        readableAddress = addressParts.isEmpty
            ? 'Address unavailable'
            : addressParts.join(', ');

        isLoadingAddress = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        readableAddress = 'Unable to determine address';
        isLoadingAddress = false;
      });

      debugPrint('Reverse geocoding error: $error');
    }
  }

  Future<void> openInGoogleMaps() async {
    final latitude =
        (widget.visit['latitude'] as num?)?.toDouble();

    final longitude =
        (widget.visit['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      showMessage('Location coordinates are unavailable.');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$latitude,$longitude',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        showMessage('Unable to open Google Maps.');
      }
    } catch (error) {
      if (!mounted) return;

      showMessage('Unable to open Google Maps: $error');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String formatVisitTime(DateTime visitTime) {
    final day = visitTime.day.toString().padLeft(2, '0');
    final month = visitTime.month.toString().padLeft(2, '0');
    final year = visitTime.year;

    final hour = visitTime.hour.toString().padLeft(2, '0');
    final minute = visitTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;

    final rawProfile = visit['profiles'];

    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};

    final salespersonName =
        profile['full_name']?.toString() ?? 'Unknown salesperson';

    final visitedAt = visit['visited_at']?.toString();

    final visitTime = visitedAt == null
        ? null
        : DateTime.tryParse(visitedAt)?.toLocal();

    final notes = visit['notes']?.toString();

    final latitude =
        (visit['latitude'] as num?)?.toDouble();

    final longitude =
        (visit['longitude'] as num?)?.toDouble();

    final hasCoordinates =
        latitude != null && longitude != null;

    final storeId = visit['store_id']?.toString();
    final storeName =
        visit['store_name']?.toString() ?? 'Unknown store';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildPhotoSection(context),

          const SizedBox(height: 24),

          Text(
            storeName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerHistoryScreen(
                      storeId: storeId,
                      storeName: storeName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text(
                'VIEW CUSTOMER HISTORY',
              ),
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
            value: visitTime == null
                ? 'Time unavailable'
                : formatVisitTime(visitTime),
          ),

          _buildLocationSection(
            context,
            hasCoordinates: hasCoordinates,
          ),

          const SizedBox(height: 24),

          _buildNotesSection(
            context,
            notes: notes,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    if (isLoadingPhoto) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (signedPhotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          signedPhotoUrl!,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const _PhotoPlaceholder(
              message: 'Unable to display photo',
            );
          },
        ),
      );
    }

    return const _PhotoPlaceholder(
      message: 'No photo available',
    );
  }

  Widget _buildLocationSection(
    BuildContext context, {
    required bool hasCoordinates,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style:
                        Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),

                  if (isLoadingAddress)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    )
                  else
                    Text(
                      readableAddress ?? 'Address unavailable',
                      style:
                          Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          ],
        ),

        if (hasCoordinates) ...[
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: openInGoogleMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text(
                'OPEN IN GOOGLE MAPS',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection(
    BuildContext context, {
    required String? notes,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes_outlined),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style:
                    Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                notes == null || notes.trim().isEmpty
                    ? 'No notes provided.'
                    : notes,
                style:
                    Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(message),
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
      padding: const EdgeInsets.only(bottom: 18),
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
                  style:
                      Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style:
                      Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}