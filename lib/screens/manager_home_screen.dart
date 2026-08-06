import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visit_detail_screen.dart';

enum VisitPeriod {
  today,
  yesterday,
  last7Days,
  thisMonth,
}

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  bool isLoading = true;

  VisitPeriod selectedPeriod = VisitPeriod.today;

  List<Map<String, dynamic>> visits = [];

  int visitCount = 0;
  int activeSalespersonCount = 0;
  int storeCount = 0;

  @override
  void initState() {
    super.initState();
    loadVisits();
  }

  DateTimeRange getSelectedDateRange() {
    final now = DateTime.now();

    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    switch (selectedPeriod) {
      case VisitPeriod.today:
        return DateTimeRange(
          start: startOfToday,
          end: startOfToday.add(
            const Duration(days: 1),
          ),
        );

      case VisitPeriod.yesterday:
        final startOfYesterday = startOfToday.subtract(
          const Duration(days: 1),
        );

        return DateTimeRange(
          start: startOfYesterday,
          end: startOfToday,
        );

      case VisitPeriod.last7Days:
        final startOfPeriod = startOfToday.subtract(
          const Duration(days: 6),
        );

        return DateTimeRange(
          start: startOfPeriod,
          end: startOfToday.add(
            const Duration(days: 1),
          ),
        );

      case VisitPeriod.thisMonth:
        final startOfMonth = DateTime(
          now.year,
          now.month,
          1,
        );

        final startOfNextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);

        return DateTimeRange(
          start: startOfMonth,
          end: startOfNextMonth,
        );
    }
  }

  Future<void> loadVisits() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final dateRange = getSelectedDateRange();

      final data = await Supabase.instance.client
          .from('visits')
          .select('''
            id,
            salesperson_id,
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
          .gte(
            'visited_at',
            dateRange.start.toUtc().toIso8601String(),
          )
          .lt(
            'visited_at',
            dateRange.end.toUtc().toIso8601String(),
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
            (visit) =>
                visit['store_id']?.toString() ??
                visit['store_name']
                    ?.toString()
                    .trim()
                    .toLowerCase(),
          )
          .whereType<String>()
          .where((value) => value.isNotEmpty)
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

  Future<void> changePeriod(
    VisitPeriod period,
  ) async {
    if (period == selectedPeriod) {
      return;
    }

    setState(() {
      selectedPeriod = period;
    });

    await loadVisits();
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  String get selectedPeriodLabel {
    switch (selectedPeriod) {
      case VisitPeriod.today:
        return 'Today';

      case VisitPeriod.yesterday:
        return 'Yesterday';

      case VisitPeriod.last7Days:
        return 'Last 7 Days';

      case VisitPeriod.thisMonth:
        return 'This Month';
    }
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

  String formatDate(String? value) {
    if (value == null) {
      return '';
    }

    final dateTime = DateTime.tryParse(value)?.toLocal();

    if (dateTime == null) {
      return '';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');

    return '$day/$month';
  }

  bool get shouldShowDate {
    return selectedPeriod != VisitPeriod.today &&
        selectedPeriod != VisitPeriod.yesterday;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Visit Tracker'),
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
      body: RefreshIndicator(
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
              child: Text(
                'Visit History',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 12),

            _PeriodSelector(
              selectedPeriod: selectedPeriod,
              onChanged: changePeriod,
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 80,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Text(
                  selectedPeriodLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 12),

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
                            label: 'Visits',
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
                            label: 'Visits',
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
                  'Visits',
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 48,
                  ),
                  child: Center(
                    child: Text(
                      'No visits for ${selectedPeriodLabel.toLowerCase()}.',
                      textAlign: TextAlign.center,
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

                    final time = formatTime(
                      visit['visited_at']?.toString(),
                    );

                    final date = formatDate(
                      visit['visited_at']?.toString(),
                    );

                    final trailingText = shouldShowDate
                        ? '$date\n$time'
                        : time;

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
                              trailingText,
                              textAlign: TextAlign.right,
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
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final VisitPeriod selectedPeriod;
  final ValueChanged<VisitPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: SegmentedButton<VisitPeriod>(
        segments: const [
          ButtonSegment(
            value: VisitPeriod.today,
            label: Text('Today'),
            icon: Icon(Icons.today_outlined),
          ),
          ButtonSegment(
            value: VisitPeriod.yesterday,
            label: Text('Yesterday'),
          ),
          ButtonSegment(
            value: VisitPeriod.last7Days,
            label: Text('7 Days'),
          ),
          ButtonSegment(
            value: VisitPeriod.thisMonth,
            label: Text('Month'),
          ),
        ],
        selected: {
          selectedPeriod,
        },
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;

          onChanged(selection.first);
        },
        showSelectedIcon: false,
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