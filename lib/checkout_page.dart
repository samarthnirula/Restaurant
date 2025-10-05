import 'package:flutter/material.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Enter your details to place the order'),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Address'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Place Order'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Order Placed'),
                    content: Text('Your order has been placed successfully!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
