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

  @override
  Widget build(BuildContext context) {
    final pages = const [
      PartsManagementPage(),
      ServiceOrdersPage(),
      EmployeesPage(),
      SearchPartsPage(),
      FinancesPage(),
    ];

    return AppShell(
      currentIndex: _index,
      onNavigate: (i) => setState(() => _index = i),
      child: IndexedStack(index: _index, children: pages),
    );
  }
}
