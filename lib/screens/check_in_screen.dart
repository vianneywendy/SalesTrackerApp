import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final notesController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();

  Map<String, dynamic>? selectedStore;
  List<Map<String, dynamic>> stores = [];

  XFile? capturedPhoto;
  Position? capturedPosition;

  bool isLoadingStores = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  String normalizeStoreName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
  }

  String cleanStoreName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> loadStores() async {
    if (mounted) {
      setState(() {
        isLoadingStores = true;
      });
    }

    try {
      final data = await Supabase.instance.client
          .from('stores')
          .select(
            'id, name, address, normalized_name, is_active',
          )
          .eq('is_active', true)
          .order('name');

      final loadedStores = data
          .map<Map<String, dynamic>>(
            (store) => Map<String, dynamic>.from(store),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        stores = loadedStores;
        isLoadingStores = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingStores = false;
      });

      showMessage(
        'Unable to load stores: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingStores = false;
      });

      showMessage('Unable to load stores: $error');
    }
  }

  Future<Map<String, dynamic>?> addNewStore(
    String enteredName,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage(
        'Your login session has expired. Please log in again.',
      );
      return null;
    }

    final cleanedName = cleanStoreName(enteredName);
    final normalizedName = normalizeStoreName(enteredName);

    if (cleanedName.isEmpty) {
      showMessage('Please enter a store name.');
      return null;
    }

    // Check the stores already loaded into the app first.
    final localMatch = stores.where((store) {
      final existingNormalized =
          store['normalized_name']?.toString() ??
              normalizeStoreName(
                store['name']?.toString() ?? '',
              );

      return existingNormalized == normalizedName;
    }).firstOrNull;

    if (localMatch != null) {
      return localMatch;
    }

    try {
      final insertedStore = await Supabase.instance.client
          .from('stores')
          .insert({
            'name': cleanedName,
            'normalized_name': normalizedName,
            'created_by': user.id,
            'is_active': true,
          })
          .select(
            'id, name, address, normalized_name, is_active',
          )
          .single();

      final newStore = Map<String, dynamic>.from(
        insertedStore,
      );

      if (mounted) {
        setState(() {
          stores = [
            ...stores,
            newStore,
          ]..sort(
              (first, second) => first['name']
                  .toString()
                  .toLowerCase()
                  .compareTo(
                    second['name']
                        .toString()
                        .toLowerCase(),
                  ),
            );
        });
      }

      return newStore;
    } on PostgrestException catch (error) {
      // PostgreSQL code 23505 means the normalized name
      // already exists, possibly added by another user.
      if (error.code == '23505') {
        try {
          final existingStore = await Supabase.instance.client
              .from('stores')
              .select(
                'id, name, address, normalized_name, is_active',
              )
              .eq('normalized_name', normalizedName)
              .eq('is_active', true)
              .single();

          final store = Map<String, dynamic>.from(
            existingStore,
          );

          await loadStores();

          return store;
        } catch (fetchError) {
          showMessage(
            'This store already exists, but it could not be loaded.',
          );
          return null;
        }
      }

      showMessage(
        'Unable to add store: ${error.message}',
      );

      return null;
    } catch (error) {
      showMessage('Unable to add store: $error');
      return null;
    }
  }

  Future<void> chooseStore() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _StorePickerDialog(
          stores: stores,
          onAddStore: addNewStore,
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      selectedStore = result;
    });
  }

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
    final store = selectedStore;
    final notes = notesController.text.trim();

    if (store == null) {
      showMessage('Please select a store.');
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

    String? uploadedPhotoPath;

    try {
      final photoFile = File(capturedPhoto!.path);

      final extension = path.extension(photoFile.path).isEmpty
          ? '.jpg'
          : path.extension(photoFile.path);

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}'
          '$extension';

      await Supabase.instance.client.storage
          .from('visit-photos')
          .upload(
            fileName,
            photoFile,
          );

      uploadedPhotoPath = fileName;

      await Supabase.instance.client.from('visits').insert({
        'salesperson_id': user.id,
        'store_id': store['id'],
        'store_name': store['name'],
        'latitude': capturedPosition!.latitude,
        'longitude': capturedPosition!.longitude,
        'accuracy_meters': capturedPosition!.accuracy,
        'photo_path': uploadedPhotoPath,
        'notes': notes.isEmpty ? null : notes,
        'visited_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visit submitted successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      showMessage(
        'Database error: ${error.message}',
      );
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
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedStoreName =
        selectedStore?['name']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Store',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge,
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: isSubmitting || isLoadingStores
                  ? null
                  : chooseStore,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon:
                      const Icon(Icons.store_outlined),
                  suffixIcon: isLoadingStores
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_drop_down,
                        ),
                ),
                child: Text(
                  isLoadingStores
                      ? 'Loading stores...'
                      : selectedStoreName ??
                          'Select or add a store',
                  style: selectedStoreName == null
                      ? Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          )
                      : Theme.of(context)
                          .textTheme
                          .bodyLarge,
                ),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed:
                  isSubmitting ? null : takePhoto,
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
              onPressed: isSubmitting
                  ? null
                  : captureLocation,
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
                'Approximate location captured',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
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
                onPressed: isSubmitting
                    ? null
                    : submitVisit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
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

class _StorePickerDialog extends StatefulWidget {
  const _StorePickerDialog({
    required this.stores,
    required this.onAddStore,
  });

  final List<Map<String, dynamic>> stores;

  final Future<Map<String, dynamic>?> Function(
    String storeName,
  ) onAddStore;

  @override
  State<_StorePickerDialog> createState() =>
      _StorePickerDialogState();
}

class _StorePickerDialogState
    extends State<_StorePickerDialog> {
  final searchController = TextEditingController();

  String searchText = '';
  bool isAddingStore = false;

  String normalize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
  }

  List<Map<String, dynamic>> get filteredStores {
    final normalizedSearch = normalize(searchText);

    if (normalizedSearch.isEmpty) {
      return widget.stores;
    }

    return widget.stores.where((store) {
      final storeName =
          store['name']?.toString() ?? '';

      return normalize(storeName)
          .contains(normalizedSearch);
    }).toList();
  }

  bool get exactStoreExists {
    final normalizedSearch = normalize(searchText);

    if (normalizedSearch.isEmpty) {
      return false;
    }

    return widget.stores.any((store) {
      final normalizedStoreName =
          store['normalized_name']?.toString() ??
              normalize(
                store['name']?.toString() ?? '',
              );

      return normalizedStoreName == normalizedSearch;
    });
  }

  Future<void> addStore() async {
    final enteredName = searchController.text.trim();

    if (enteredName.isEmpty || isAddingStore) {
      return;
    }

    setState(() {
      isAddingStore = true;
    });

    final newStore = await widget.onAddStore(
      enteredName,
    );

    if (!mounted) return;

    setState(() {
      isAddingStore = false;
    });

    if (newStore != null) {
      Navigator.of(context).pop(newStore);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = filteredStores;
    final enteredName =
        searchController.text.trim();

    return AlertDialog(
      title: const Text('Select Store'),
      contentPadding:
          const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              textCapitalization:
                  TextCapitalization.words,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Search store',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Flexible(
              child: matches.isEmpty
                  ? const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical: 24,
                      ),
                      child: Text(
                        'No matching store found.',
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder:
                          (context, index) =>
                              const Divider(
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final store = matches[index];

                        return ListTile(
                          leading: const Icon(
                            Icons.store_outlined,
                          ),
                          title: Text(
                            store['name']
                                    ?.toString() ??
                                'Unnamed store',
                          ),
                          subtitle:
                              store['address'] == null ||
                                      store['address']
                                          .toString()
                                          .trim()
                                          .isEmpty
                                  ? null
                                  : Text(
                                      store['address']
                                          .toString(),
                                    ),
                          onTap: () {
                            Navigator.of(context)
                                .pop(store);
                          },
                        );
                      },
                    ),
            ),

            if (enteredName.isNotEmpty &&
                !exactStoreExists) ...[
              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: isAddingStore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.add_circle_outline,
                      ),
                title: Text(
                  'Add "$enteredName"',
                ),
                subtitle: const Text(
                  'Save this store for future visits',
                ),
                enabled: !isAddingStore,
                onTap:
                    isAddingStore ? null : addStore,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isAddingStore
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}