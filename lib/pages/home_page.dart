import 'package:flutter/material.dart';
import '../widgets/app_shell.dart';
import 'parts_management_page.dart';
import 'service_orders_page.dart';
import 'employees_page.dart';
import 'search_parts_page.dart';
import 'finances_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = [
    PartsManagementPage(),
    ServiceOrdersPage(),
    EmployeesPage(),
    SearchPartsPage(),
    FinancesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _index,
      onNavigate: (i) => setState(() => _index = i),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _pages[_index],
        ),
      ),
    );
  }
}
