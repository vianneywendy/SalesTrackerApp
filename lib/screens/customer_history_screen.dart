import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String? storeId;
  final String storeName;

  @override
  State<CustomerHistoryScreen> createState() =>
      _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState
    extends State<CustomerHistoryScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> visits = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final List<dynamic> data;

      if (widget.storeId != null &&
          widget.storeId!.isNotEmpty) {
        data = await Supabase.instance.client
            .from('visits')
            .select('''
              id,
              store_id,
              store_name,
              visited_at,
              notes,
              photo_path,
              latitude,
              longitude,
              accuracy_meters,
              profiles!visits_salesperson_id_fkey(full_name)
            ''')
            .eq('store_id', widget.storeId!)
            .order('visited_at', ascending: false);
      } else {
        // Older visits may not have store_id, so use the
        // saved store name as a fallback.
        data = await Supabase.instance.client
            .from('visits')
            .select('''
              id,
              store_id,
              store_name,
              visited_at,
              notes,
              photo_path,
              latitude,
              longitude,
              accuracy_meters,
              profiles!visits_salesperson_id_fkey(full_name)
            ''')
            .eq('store_name', widget.storeName)
            .order('visited_at', ascending: false);
      }

      final loadedVisits = data
          .map<Map<String, dynamic>>(
            (visit) => Map<String, dynamic>.from(
              visit as Map,
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        visits = loadedVisits;
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
            'Unable to load customer history: $error',
          ),
        ),
      );
    }
  }

  int get visitsPast30Days {
    final cutoff = DateTime.now().subtract(
      const Duration(days: 30),
    );

    return visits.where((visit) {
      final visitedAt = DateTime.tryParse(
        visit['visited_at']?.toString() ?? '',
      )?.toLocal();

      return visitedAt != null &&
          !visitedAt.isBefore(cutoff);
    }).length;
  }

  Map<String, dynamic>? get latestVisit {
    return visits.isEmpty ? null : visits.first;
  }

  String salespersonName(
    Map<String, dynamic> visit,
  ) {
    final rawProfile = visit['profiles'];

    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};

    return profile['full_name']?.toString() ??
        'Unknown salesperson';
  }

  String formatDateTime(String? value) {
    final dateTime =
        DateTime.tryParse(value ?? '')?.toLocal();

    if (dateTime == null) {
      return 'Unknown';
    }

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final visitDay = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    String dateLabel;

    if (visitDay == today) {
      dateLabel = 'Today';
    } else if (visitDay ==
        today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      final day =
          dateTime.day.toString().padLeft(2, '0');
      final month =
          dateTime.month.toString().padLeft(2, '0');

      dateLabel = '$day/$month/${dateTime.year}';
    }

    final hour =
        dateTime.hour.toString().padLeft(2, '0');
    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$dateLabel, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final latest = latestVisit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadHistory,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.storeName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _CustomerSummaryCard(
                    lastVisit: latest == null
                        ? 'No visits recorded'
                        : formatDateTime(
                            latest['visited_at']
                                ?.toString(),
                          ),
                    visitsPast30Days:
                        visitsPast30Days,
                    latestSalesperson: latest == null
                        ? '-'
                        : salespersonName(latest),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Visit History',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 48,
                      ),
                      child: Center(
                        child: Text(
                          'No visit history available.',
                        ),
                      ),
                    )
                  else
                    ...visits.map(
                      (visit) {
                        final notes =
                            visit['notes']?.toString();

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(
                                Icons.event_available,
                              ),
                            ),
                            title: Text(
                              formatDateTime(
                                visit['visited_at']
                                    ?.toString(),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  salespersonName(visit),
                                ),
                                if (notes != null &&
                                    notes
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    notes,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ],
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

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({
    required this.lastVisit,
    required this.visitsPast30Days,
    required this.latestSalesperson,
  });

  final String lastVisit;
  final int visitsPast30Days;
  final String latestSalesperson;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _SummaryRow(
              icon: Icons.access_time,
              label: 'Last Visit',
              value: lastVisit,
            ),
            const Divider(height: 32),
            _SummaryRow(
              icon: Icons.calendar_month_outlined,
              label: 'Visited Past 30 Days',
              value: '$visitsPast30Days times',
            ),
            const Divider(height: 32),
            _SummaryRow(
              icon: Icons.person_outline,
              label: 'Latest Salesperson',
              value: latestSalesperson,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
    );
  }
}
