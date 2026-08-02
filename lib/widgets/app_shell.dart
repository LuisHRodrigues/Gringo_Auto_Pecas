import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

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
  NavItem('Buscar Peças', Icons.search),
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

  Widget _logo(VoidCallback onTap, {required bool showText}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/icons/wrench.png',
              width: 30,
              height: 30,
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('GMP Gestor',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Gestão de Oficina',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.mutedForeground)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _userMenu(AuthProvider auth, User? user) {
    return PopupMenuButton<String>(
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
                      fontSize: 12, color: AppColors.mutedForeground)),
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
        radius: 22,
        backgroundColor: AppColors.secondary,
        foregroundImage:
            (user?.avatar != null && user!.avatar!.startsWith('http'))
                ? NetworkImage(user.avatar!)
                : null,
        child: Text(
          user != null ? _initials(user.name) : 'U',
          style: const TextStyle(
              fontSize: 16,
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _navRow(bool showLabel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < navItems.length; i++)
            _NavButton(
              item: navItems[i],
              active: currentIndex == i,
              showLabel: showLabel,
              onTap: () => onNavigate(i),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1024;
    // Abaixo desse ponto não sobra espaço suficiente pra logo, navegação e
    // avatar dividirem a barra sem se sobrepor, então a navegação passa a
    // ocupar só o espaço central (em vez de se centralizar na barra toda).
    final isCompact = width < 700;

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
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
              height: 80,
              child: isCompact
                  ? Row(
                      children: [
                        _logo(() => onNavigate(0), showText: false),
                        const SizedBox(width: 4),
                        Expanded(child: _navRow(false)),
                        const SizedBox(width: 8),
                        _userMenu(auth, user),
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        // Navegação, centralizada na largura total da barra
                        Align(
                          alignment: Alignment.center,
                          child: _navRow(isWide),
                        ),
                        // Logo e menu do usuário, sobrepostos nas pontas
                        Row(
                          children: [
                            _logo(() => onNavigate(0), showText: true),
                            const Spacer(),
                            _userMenu(auth, user),
                          ],
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
        icon: Icon(item.icon, size: 20),
        label: showLabel
            ? Text(item.label, style: const TextStyle(fontSize: 15))
            : const SizedBox.shrink(),
        style: TextButton.styleFrom(
          foregroundColor:
              active ? AppColors.accentForeground : AppColors.foreground,
          backgroundColor: active ? AppColors.accent : Colors.transparent,
          padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 16 : 12, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
