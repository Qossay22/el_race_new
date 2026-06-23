import 'package:flutter/material.dart';
import 'package:el_race/ui/widgets/global_search_screen.dart';
import 'package:el_race/providers/global_search_provider.dart';
import 'package:provider/provider.dart';

/// Example implementations showing how to integrate Global Search
/// into different parts of your app

/// ============================================
/// Example 1: Add Search Icon to AppBar
/// ============================================
class HomeScreenWithSearch extends StatelessWidget {
  const HomeScreenWithSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Search icon button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Home Content'),
      ),
    );
  }
}

/// ============================================
/// Example 2: Add Search to Menu/Drawer
/// ============================================
class AppDrawerWithSearch extends StatelessWidget {
  const AppDrawerWithSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Menu',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),

          // Search menu item
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Global Search'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalSearchScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.work),
            title: const Text('Projects'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// ============================================
/// Example 3: Floating Action Button
/// ============================================
class ScreenWithSearchFAB extends StatelessWidget {
  const ScreenWithSearchFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: const Center(child: Text('Task List')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GlobalSearchScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFBA1719),
        child: const Icon(Icons.search),
      ),
    );
  }
}

/// ============================================
/// Example 4: Bottom Navigation with Search
/// ============================================
class MainScreenWithBottomNav extends StatefulWidget {
  const MainScreenWithBottomNav({super.key});

  @override
  State<MainScreenWithBottomNav> createState() =>
      _MainScreenWithBottomNavState();
}

class _MainScreenWithBottomNavState extends State<MainScreenWithBottomNav> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EL Race'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
        ],
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('Home'));
      case 1:
        return const Center(child: Text('Projects'));
      case 2:
        return const Center(child: Text('Tasks'));
      default:
        return const Center(child: Text('Home'));
    }
  }
}

/// ============================================
/// Example 5: Programmatic Search
/// ============================================
/// Use this when you want to trigger search from code
/// without showing the full search UI

class ProgrammaticSearchExample extends StatelessWidget {
  const ProgrammaticSearchExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GlobalSearchProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Quick Search')),
        body: Consumer<GlobalSearchProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Quick search buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          provider.search(
                            category: 'tasks',
                            keyword: 'urgent',
                          );
                        },
                        child: const Text('Urgent Tasks'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          provider.search(
                            category: 'petty_cash',
                            keyword: 'pending',
                          );
                        },
                        child: const Text('Pending Expenses'),
                      ),
                    ],
                  ),
                ),

                // Results
                Expanded(
                  child: _buildResults(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults(GlobalSearchProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.errorMessage ?? 'Error'),
            ElevatedButton(
              onPressed: () => provider.retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.results.isEmpty) {
      return const Center(child: Text('No results'));
    }

    return ListView.builder(
      itemCount: provider.results.length,
      itemBuilder: (context, index) {
        final item = provider.results[index];
        return ListTile(
          title: Text(item.title),
          subtitle: Text(item.subtitle ?? ''),
          trailing: Text(item.displayCategory),
        );
      },
    );
  }
}

/// ============================================
/// Example 6: Add to Existing Landing Screen
/// ============================================
/// Modify your existing landing screen to add search
///
/// In lib/ui/presentation/landing_screen/screens/landing_screen.dart
///
/// Add this to your AppBar:
/// ```dart
/// actions: [
///   IconButton(
///     icon: const Icon(Icons.search),
///     onPressed: () {
///       Navigator.push(
///         context,
///         MaterialPageRoute(
///           builder: (_) => const GlobalSearchScreen(),
///         ),
///       );
///     },
///   ),
/// ],
/// ```

/// ============================================
/// Example 7: Quick Search Card/Widget
/// ============================================
class QuickSearchCard extends StatelessWidget {
  const QuickSearchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GlobalSearchScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search tasks, projects, expenses...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================
/// Example 8: Deep Link to Search
/// ============================================
/// Add route in lib/utils/generated_routes.dart:
/// 
/// ```dart
/// case '/global_search':
///   return CupertinoPageRoute(
///     builder: (_) => const GlobalSearchScreen(),
///   );
/// ```
/// 
/// Then navigate using:
/// ```dart
/// Navigator.pushNamed(context, '/global_search');
/// ```

/// ============================================
/// Example 9: Search with Pre-filled Category
/// ============================================
/// If you want to open search with a specific category
/// (requires modifying GlobalSearchScreen to accept initial category)
/// 
/// Future enhancement - GlobalSearchScreen could accept:
/// ```dart
/// class GlobalSearchScreen extends StatefulWidget {
///   final String? initialCategory;
///   final String? initialKeyword;
///   
///   const GlobalSearchScreen({
///     super.key,
///     this.initialCategory,
///     this.initialKeyword,
///   });
/// }
/// ```

/// ============================================
/// Example 10: Search from Notification
/// ============================================
/// Handle notification taps to open search
/// 
/// In your notification handler:
/// ```dart
/// void _handleNotificationTap(Map<String, dynamic> data) {
///   final type = data['type'];
///   final keyword = data['keyword'];
///   
///   Navigator.push(
///     context,
///     MaterialPageRoute(
///       builder: (_) => const GlobalSearchScreen(
///         // Pass initial values if modified to accept them
///       ),
///     ),
///   );
/// }
/// ```
