import 'package:flutter/material.dart';

class ItemDetailsPage extends StatelessWidget {
  const ItemDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String itemName =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: Text(itemName)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Details for $itemName',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Add to Cart'),
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ],
        ),
      ),
    );
  }
}
