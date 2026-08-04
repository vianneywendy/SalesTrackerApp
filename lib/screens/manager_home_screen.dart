import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visit_detail_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> visits = [];

  int visitCount = 0;
  int activeSalespersonCount = 0;
  int storeCount = 0;

  @override
  void initState() {
    super.initState();
    loadVisits();
  }

  Future<void> loadVisits() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final now = DateTime.now();

      final startOfDayLocal = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final endOfDayLocal = startOfDayLocal.add(
        const Duration(days: 1),
      );

      final data = await Supabase.instance.client
          .from('visits')
          .select('''
            id,
            salesperson_id,
            store_name,
            visited_at,
            notes,
            photo_path,
            latitude,
            longitude,
            accuracy_meters,
            profiles!visits_salesperson_id_fkey(full_name)
          ''')
          .gte(
            'visited_at',
            startOfDayLocal.toUtc().toIso8601String(),
          )
          .lt(
            'visited_at',
            endOfDayLocal.toUtc().toIso8601String(),
          )
          .order(
            'visited_at',
            ascending: false,
          );

      final loadedVisits = data
          .map<Map<String, dynamic>>(
            (visit) => Map<String, dynamic>.from(visit),
          )
          .toList();

      final uniqueSalespeople = loadedVisits
          .map(
            (visit) => visit['salesperson_id']?.toString(),
          )
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final uniqueStores = loadedVisits
          .map(
            (visit) => visit['store_name']
                ?.toString()
                .trim()
                .toLowerCase(),
          )
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet();

      if (!mounted) return;

      setState(() {
        visits = loadedVisits;

        visitCount = loadedVisits.length;
        activeSalespersonCount = uniqueSalespeople.length;
        storeCount = uniqueStores.length;

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load visits: $error',
          ),
        ),
      );
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  String formatTime(String? value) {
    if (value == null) {
      return '--:--';
    }

    final dateTime = DateTime.tryParse(value)?.toLocal();

    if (dateTime == null) {
      return '--:--';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Visits"),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadVisits,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadVisits,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: 16,
                  bottom: 24,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final useSingleColumn =
                            constraints.maxWidth < 520;

                        if (useSingleColumn) {
                          return Column(
                            children: [
                              _SummaryCard(
                                icon: Icons.location_on_outlined,
                                label: 'Visits Today',
                                value: visitCount,
                              ),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                icon: Icons.people_outline,
                                label: 'Active Salespeople',
                                value: activeSalespersonCount,
                              ),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                icon: Icons.store_outlined,
                                label: 'Stores Visited',
                                value: storeCount,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                icon: Icons.location_on_outlined,
                                label: 'Visits Today',
                                value: visitCount,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                icon: Icons.people_outline,
                                label: 'Active Salespeople',
                                value: activeSalespersonCount,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                icon: Icons.store_outlined,
                                label: 'Stores Visited',
                                value: storeCount,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Text(
                      'Recent Visits',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 48,
                      ),
                      child: Center(
                        child: Text(
                          'No visits today.',
                        ),
                      ),
                    )
                  else
                    ...visits.map(
                      (visit) {
                        final rawProfile = visit['profiles'];

                        final profile = rawProfile is Map
                            ? Map<String, dynamic>.from(
                                rawProfile,
                              )
                            : <String, dynamic>{};

                        final salespersonName =
                            profile['full_name']?.toString() ??
                                'Unknown salesperson';

                        final storeName =
                            visit['store_name']?.toString() ??
                                'Unknown store';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VisitDetailScreen(
                                    visit: visit,
                                  ),
                                ),
                              );
                            },
                            leading: const CircleAvatar(
                              child: Icon(
                                Icons.store_outlined,
                              ),
                            ),
                            title: Text(storeName),
                            subtitle: Text(salespersonName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatTime(
                                    visit['visited_at']
                                        ?.toString(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}