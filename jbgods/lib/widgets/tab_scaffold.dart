import 'package:flutter/material.dart';

class TabScaffold extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final List<Widget> children;
  /// Badge count for Chat tab (index 1)
  final int chatBadgeCount;
  /// Badge count for Events tab (index 2)
  final int eventsBadgeCount;

  const TabScaffold({
    required this.currentIndex,
    required this.onTabSelected,
    required this.children,
    this.chatBadgeCount = 0,
    this.eventsBadgeCount = 0,
    super.key,
  });

  Widget _buildNavIcon(IconData icon, int badgeCount) {
    if (badgeCount <= 0) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: children),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: onTabSelected,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Home'),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.campaign, chatBadgeCount),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.calendar_today, eventsBadgeCount),
            label: 'Events',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Rinks'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}