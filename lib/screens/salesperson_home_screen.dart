import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'check_in_screen.dart';

class SalespersonHomeScreen extends StatefulWidget {
  const SalespersonHomeScreen({super.key});

  @override
  State<SalespersonHomeScreen> createState() => _SalespersonHomeScreenState();
}

class _SalespersonHomeScreenState extends State<SalespersonHomeScreen> {
  String fullName = 'Salesperson';
  int todayVisitCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc();

      final endOfDay = startOfDay.add(
        const Duration(days: 1),
      );

      final visits = await Supabase.instance.client
          .from('visits')
          .select('id')
          .eq('salesperson_id', user.id)
          .gte('visited_at', startOfDay.toIso8601String())
          .lt('visited_at', endOfDay.toIso8601String());

      if (!mounted) return;

      setState(() {
        fullName = profile['full_name'] ?? 'Salesperson';
        todayVisitCount = visits.length;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load dashboard: $error'),
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

  Future<void> openCheckIn() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CheckInScreen(),
      ),
    );

    if (result == true) {
      loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Visit Tracker'),
        actions: [
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
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Hello, $fullName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ready for your next customer visit?',
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            "Today's Visits",
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$todayVisitCount',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: openCheckIn,
                      icon: const Icon(Icons.location_on),
                      label: const Text(
                        'CHECK IN',
                        style: TextStyle(
                          fontSize: 18,
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