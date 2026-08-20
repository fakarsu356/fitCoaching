import 'package:flutter/material.dart';

import 'daily_screen.dart';
import 'student_coach_screen.dart';
import 'student_profile_screen.dart';
import 'workout_screen.dart';

/// Öğrencinin ana kabuğu: alt sekme çubuğu ile ekranlar arası geçiş.
///
/// Öğrenci koç isteği beklerken de uygulamada gezinebilsin diye tüm sekmeler
/// her durumda açık; koçu olmayanın antrenman programı boş gelir, bu bilgiyi
/// ekranların kendisi verir.
///
/// [IndexedStack] kullanılıyor ki sekme değiştirince ekranlar sıfırlanmasın —
/// Günlük'te seçili tarih, Koçum'daki liste durumu korunur.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DailyScreen(),
          WorkoutScreen(),
          StudentCoachScreen(),
          StudentProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Günlük',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Antrenman',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_outlined),
            selectedIcon: Icon(Icons.sports),
            label: 'Koçum',
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
