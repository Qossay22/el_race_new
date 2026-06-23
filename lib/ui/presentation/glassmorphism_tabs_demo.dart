import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphismTabsDemo extends StatefulWidget {
  const GlassmorphismTabsDemo({super.key});

  @override
  State<GlassmorphismTabsDemo> createState() => _GlassmorphismTabsDemoState();
}

class _GlassmorphismTabsDemoState extends State<GlassmorphismTabsDemo> {
  int _selectedTab = 0;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  final List<TabItem> _tabs = [
    TabItem(icon: Icons.home, label: 'Home'),
    TabItem(icon: Icons.explore, label: 'Explore'),
    TabItem(icon: Icons.favorite, label: 'Favorites'),
    TabItem(icon: Icons.person, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate opacity based on scroll position
    final double opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Add spacing for the fixed tabs bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
              // Content items
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildContentItem(index);
                  },
                  childCount: 20,
                ),
              ),
            ],
          ),
          // Glassmorphism tabs bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassmorphismTabsBar(opacity),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphismTabsBar(double opacity) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10.0 * opacity,
          sigmaY: 10.0 * opacity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1 + (0.7 * opacity)),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2 * opacity),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTab == index;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTab = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab.icon,
                              size: 24,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentItem(int index) {
    // Alternate between different colored cards for visual variety
    final colors = [
      Colors.blue[100]!,
      Colors.green[100]!,
      Colors.orange[100]!,
      Colors.purple[100]!,
      Colors.red[100]!,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors[index % colors.length],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item ${index + 1}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is content item number ${index + 1}. Scroll to see the glassmorphism effect on the tabs bar above.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class TabItem {
  final IconData icon;
  final String label;

  TabItem({required this.icon, required this.label});
}
