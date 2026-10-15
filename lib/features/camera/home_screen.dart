import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_screen.dart';

/// S04 — Client Home (container). Horizontal PageView, initial page = 1
/// (Camera). Page 0 = Timeline (M6), page 2 = History (M7) — stubs for now.
/// Android back from page 0/2 returns to page 1; back from 1 exits (UI §4).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pages;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page != 1) _go(1);
      },
      child: PageView(
        controller: _pages,
        onPageChanged: (p) => setState(() => _page = p),
        children: [
          const _StubPage(label: 'S07 Timeline — M6'),
          CameraScreen(onPage: _go),
          const _StubPage(label: 'S08 History — M7'),
        ],
      ),
    );
  }
}

class _StubPage extends StatelessWidget {
  final String label;
  const _StubPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
