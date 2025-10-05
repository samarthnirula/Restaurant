import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'cart_page.dart';
import 'home_page.dart';
import 'menu_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Stripe setup (only on mobile)
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51OkdXaDHawrxXAnNnhJb0bCRoyNRlhOiVpZqOspepipoXSTsat6c3fM9JB8i0vDeRnJCoD0yRSN1fp7uaDDuYFKs00aB9ceU4m'; // Replace with your Stripe publishable key
    Stripe.merchantIdentifier = 'merchant.com.yourapp.identifier'; // Replace with your Apple Merchant ID
  }

  // ✅ Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> sampleCartItems = [
      {'name': 'Butter Chicken', 'quantity': 2, 'price': 12.99},
      {'name': 'Paneer Tikka', 'quantity': 1, 'price': 10.99},
      {'name': 'Biryani', 'quantity': 3, 'price': 11.50},
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indian Chilli Restaurant',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const HomePage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/menu': (context) => const MenuPage(),
        '/cart': (context) => CartPage(cartItems: sampleCartItems),
      },
    );
  }
}
