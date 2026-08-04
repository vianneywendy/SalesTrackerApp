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
  List<dynamic> visits = [];

  @override
  void initState() {
    super.initState();
    loadVisits();
  }

  Future<void> loadVisits() async {
    setState(() {
      isLoading = true;
    });

    try {
      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc();

      final data = await Supabase.instance.client
          .from('visits')
          .select('''
            id,
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
            startOfDay.toIso8601String(),
          )
          .order(
            'visited_at',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        visits = data;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load visits: $error'),
        ),
      );
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Visits"),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: loadVisits,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : visits.isEmpty
              ? const Center(
                  child: Text('No visits today'),
                )
              : RefreshIndicator(
                  onRefresh: loadVisits,
                  child: ListView.builder(
                    itemCount: visits.length,
                    itemBuilder: (context, index) {
                      final visit = Map<String, dynamic>.from(
                        visits[index] as Map,
                      );

                      final profile = visit['profiles']
                          as Map<String, dynamic>?;

                      final salespersonName =
                          profile?['full_name']?.toString() ??
                              'Unknown salesperson';

                      final visitedAt = DateTime.parse(
                        visit['visited_at'] as String,
                      ).toLocal();

                      final formattedTime =
                          '${visitedAt.hour.toString().padLeft(2, '0')}:'
                          '${visitedAt.minute.toString().padLeft(2, '0')}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VisitDetailScreen(
                                  visit: visit,
                                ),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            child: Icon(Icons.store),
                          ),
                          title: Text(
                            visit['store_name']?.toString() ??
                                'Unknown store',
                          ),
                          subtitle: Text(salespersonName),
                          trailing: Text(formattedTime),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}