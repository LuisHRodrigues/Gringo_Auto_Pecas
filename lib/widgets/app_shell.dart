import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Itens do menu, na mesma ordem do top-menu-bar.tsx.
class NavItem {
  final String label;
  final IconData icon;
  const NavItem(this.label, this.icon);
}

const navItems = [
  NavItem('Peças', Icons.inventory_2_outlined),
  NavItem('Ordem de Serviço', Icons.description_outlined),
  NavItem('Funcionários', Icons.people_outline),
  NavItem('Busca de Peças', Icons.search),
  NavItem('Finanças', Icons.attach_money),
];

/// Casca comum a todas as telas internas: barra superior fixa com logo,
/// navegação central e menu do usuário, mais o conteúdo da página.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final Widget child;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.map((p) => p.isNotEmpty ? p[0] : '').join();
    return letters
        .toUpperCase()
        .substring(0, letters.length >= 2 ? 2 : letters.length);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Barra superior fixa
          Material(
            color: AppColors.card,
            elevation: 0,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 64,
              child: Row(
                children: [
                  // Logo
                  InkWell(
                    onTap: () => onNavigate(0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const PistonIcon(size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('GMP Gestor',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('Gestão de Oficina',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mutedForeground)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Navegação
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < navItems.length; i++)
                            _NavButton(
                              item: navItems[i],
                              active: currentIndex == i,
                              showLabel: isWide,
                              onTap: () => onNavigate(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Menu do usuário
                  PopupMenuButton<String>(
                    offset: const Offset(0, 48),
                    onSelected: (v) {
                      if (v == 'logout') auth.logout();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.foreground)),
                            Text(user?.email ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 16),
                            SizedBox(width: 8),
                            Text('Sair'),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.secondary,
                      foregroundImage: (user?.avatar != null &&
                              user!.avatar!.startsWith('http'))
                          ? NetworkImage(user.avatar!)
                          : null,
                      child: Text(
                        user != null ? _initials(user.name) : 'U',
                        style: const TextStyle(
                            color: AppColors.secondaryForeground,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.showLabel,
    required this.onTap,
  });
  final NavItem item;
  final bool active;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(item.icon, size: 16),
        label: showLabel ? Text(item.label) : const SizedBox.shrink(),
        style: TextButton.styleFrom(
          foregroundColor:
              active ? AppColors.accentForeground : AppColors.foreground,
          backgroundColor: active ? AppColors.accent : Colors.transparent,
          padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 12 : 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
