import 'package:flutter/material.dart';

import 'coach_profile_screen.dart';
import 'coach_requests_screen.dart';
import 'coach_students_screen.dart';
import 'coach_workouts_screen.dart';

/// Koçun ana kabuğu: alt sekme çubuğu ile ekranlar arası geçiş.
///
/// Öğrenci tarafındaki [StudentShell] ile aynı kurgu — [IndexedStack] sayesinde
/// sekme değişince ekranlar sıfırlanmaz, listelerdeki konum korunur.
class CoachShell extends StatefulWidget {
  const CoachShell({super.key});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _index = 0;

  /// İstek onaylandığında/reddedildiğinde artar; öğrenci listesi bunu dinleyip
  /// kendini tazeler. Sekmeler arka planda canlı kaldığı için iki ekranı
  /// birbirine bağlamanın en ucuz yolu bu.
  final ValueNotifier<int> _relationsVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _relationsVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CoachStudentsScreen(relationsVersion: _relationsVersion),
          CoachRequestsScreen(relationsVersion: _relationsVersion),
          CoachWorkoutsScreen(relationsVersion: _relationsVersion),
          const CoachProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Öğrencilerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'İstekler',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Programlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
