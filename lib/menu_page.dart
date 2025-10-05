import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'cart_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final DatabaseReference menuRef =
      FirebaseDatabase.instance.ref('menu_items'); // Firebase path

  // Stores menu items grouped by category
  Map<String, List<Map<String, dynamic>>> categorizedMenu = {};
  Map<String, bool> categoryExpanded = {}; // Track open/close state
  Map<String, Map<int, int>> categoryQuantities = {}; // Track quantities per category

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    try {
      final snapshot = await menuRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        // Group by category
        Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final entry in data.entries) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          final category = (item['category'] ?? 'Other').toString();

          grouped.putIfAbsent(category, () => []);
          grouped[category]!.add({
            'name': item['name'],
            'price': (item['price'] as num).toDouble(),
            'image': item['image'] ?? '',
          });
        }

        // Sort categories alphabetically
        grouped = Map.fromEntries(
          grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        );

        // Initialize states
        Map<String, Map<int, int>> qtyMap = {};
        grouped.forEach((category, items) {
          qtyMap[category] = {};
          categoryExpanded[category] = true; // default: expanded
        });

        setState(() {
          categorizedMenu = grouped;
          categoryQuantities = qtyMap;
        });
      } else {
        debugPrint('No menu data found.');
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
    }
  }

  double getTotal() {
    double total = 0;
    categoryQuantities.forEach((cat, qtyMap) {
      qtyMap.forEach((index, qty) {
        total += categorizedMenu[cat]![index]['price'] * qty;
      });
    });
    return total;
  }

  int getTotalItems() {
    int count = 0;
    categoryQuantities.forEach((_, qtyMap) {
      count += qtyMap.values.fold(0, (sum, qty) => sum + qty);
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = getTotal();
    final totalItems = getTotalItems();

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: categorizedMenu.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: categorizedMenu.entries.map((entry) {
                final category = entry.key;
                final items = entry.value;
                final qtyMap = categoryQuantities[category]!;

                return ExpansionTile(
                  title: Text(
                    category,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: categoryExpanded[category] ?? true,
                  onExpansionChanged: (expanded) {
                    setState(() => categoryExpanded[category] = expanded);
                  },
                  children: items.asMap().entries.map((itemEntry) {
                    final index = itemEntry.key;
                    final item = itemEntry.value;
                    final quantity = qtyMap[index] ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: item['image'].isNotEmpty
                          ? Image.network(
                              item['image'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image),
                            )
                          : const Icon(Icons.fastfood, size: 40),
                      title: Text(item['name'],
                          style: const TextStyle(fontSize: 18)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${item['price']}',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          quantity == 0
                              ? IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green, size: 28),
                                  onPressed: () {
                                    setState(() {
                                      qtyMap[index] = 1;
                                    });
                                  },
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[200],
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            if (qtyMap[index]! > 1) {
                                              qtyMap[index] =
                                                  qtyMap[index]! - 1;
                                            } else {
                                              qtyMap[index] = 0;
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        '${qtyMap[index]}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle,
                                            color: Colors.green),
                                        onPressed: () {
                                          setState(() {
                                            qtyMap[index] =
                                                qtyMap[index]! + 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          // Total bar
          Positioned(
            right: 70,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '\$${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Cart button
          FloatingActionButton(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart),
                if (totalItems > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$totalItems',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              // Collect cart items across categories
              final cartItems = <Map<String, dynamic>>[];
              categorizedMenu.forEach((category, items) {
                final qtyMap = categoryQuantities[category]!;
                qtyMap.entries.where((e) => e.value > 0).forEach((entry) {
                  cartItems.add({
                    'name': items[entry.key]['name'],
                    'quantity': entry.value,
                    'price': items[entry.key]['price'],
                  });
                });
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartPage(cartItems: cartItems),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
