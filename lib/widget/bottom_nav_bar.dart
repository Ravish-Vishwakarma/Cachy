import 'package:flutter/material.dart';

class MyBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const MyBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<MyBottomNavBar> createState() => _MyBottomNavBarState();
}

class _MyBottomNavBarState extends State<MyBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_rounded),
          label: "AI",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.list_rounded), label: "List"),
      ],
    );
  }
}
