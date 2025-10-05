import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/food_bg.jpg'), // Replace with your food image
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay for readability
          Container(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.5),
          ),
          // Overview content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome to Indian Chilli!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Delicious Indian food delivered fresh. Explore our menu and place your order now!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  child: Text('View Menu'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/menu');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
