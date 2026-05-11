import 'package:cachy/widget/bottom_nav_bar.dart';
import 'package:cachy/pages/ai_page.dart';
import 'package:cachy/pages/memories_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ======================= VARIABLES ======================= //
  int selectedIndex = 0;

  // ======================= FUNCTIONS ======================= //
  void changePage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bottom Navigation Bar
      bottomNavigationBar: MyBottomNavBar(
        currentIndex: selectedIndex,
        onTap: changePage,
      ),
      // AI and List Pages, Used Indexes Stack so that state don't reload every time the page is switched
      body: IndexedStack(
        index: selectedIndex,
        children: const [AIPage(), DatabasePage()],
      ),
    );
  }
}
