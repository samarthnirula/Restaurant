import 'dart:io' show Platform;
import 'dart:convert'; // ✅ Needed for jsonEncode / jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http; // ✅ Needed for HTTP calls

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({super.key, required this.cartItems});

  @override
  CartPageState createState() => CartPageState();
}

class CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> cart;
  String orderType = 'pickup'; // pickup | delivery

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final double texasTaxRate = 0.0825;
  CardFieldInputDetails? cardDetails;

  @override
  void initState() {
    super.initState();
    cart = List<Map<String, dynamic>>.from(widget.cartItems);
  }

  double getSubtotal() {
    double subtotal = 0;
    for (var item in cart) {
      subtotal += item['price'] * item['quantity'];
    }
    return subtotal;
  }

  double getTax() => getSubtotal() * texasTaxRate;
  double getTotal() => getSubtotal() + getTax();

  /// ✅ Calls your backend (Cloud Function or local test server)
  Future<String> _fetchClientSecretFromFunction(int amountCents) async {
    final url = Uri.parse(
        'https://stripe-payment-intent.indianchilli.workers.dev'); 
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amountCents}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create PaymentIntent: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['clientSecret'];
  }

  Future<void> handlePayment() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in your name and phone number')),
      );
      return;
    }

    if (orderType == 'delivery' && addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your delivery address')),
      );
      return;
    }

    if (cardDetails == null || !cardDetails!.complete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete card details')),
      );
      return;
    }

    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: nameController.text,
              phone: phoneController.text,
              address: Address(
                city: '',
                country: 'US',
                line1: addressController.text,
                line2: '',
                postalCode: '',
                state: 'TX',
              ),
            ),
          ),
        ),
      );

      debugPrint("PaymentMethod created: ${paymentMethod.id}");

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order Placed'),
          content: Text(orderType == 'pickup'
              ? 'Your pickup order has been placed successfully!'
              : 'Your delivery order has been placed successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint("Stripe error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  Future<void> handlePaymentSheet() async {
  try {
    final amountCents = (getTotal() * 100).toInt();

    // Fetch clientSecret from Cloudflare Worker
    final response = await http.post(
      Uri.parse("https://stripe-payment-intent.indianchilli.workers.dev"), 
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"amount": amountCents}),
    );

    debugPrint("Response status: ${response.statusCode}");
    debugPrint("Response body: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch client secret");
    }

    final data = jsonDecode(response.body);
    final clientSecret = data["clientSecret"];

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Indian Chilli Restaurant',
        style: ThemeMode.system,
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'US',
          testEnv: true,
        ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Order Placed'),
        content: Text('Your payment was successful!'),
      ),
    );
  } catch (e) {
    debugPrint('Payment Sheet Error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        title: Text(item['name']),
                        subtitle: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  if (item['quantity'] > 1) {
                                    item['quantity'] -= 1;
                                  } else {
                                    cart.removeAt(index);
                                  }
                                });
                              },
                            ),
                            Text('${item['quantity']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () {
                                setState(() {
                                  item['quantity'] += 1;
                                });
                              },
                            ),
                          ],
                        ),
                        trailing: Text(
                          '\$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Choose Order Type:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('In-Store Pickup'),
                          value: 'pickup',
                          groupValue: orderType,
                          onChanged: (value) => setState(() => orderType = value!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Delivery'),
                          value: 'delivery',
                          groupValue: orderType,
                          onChanged: (value) => setState(() => orderType = value!),
                        ),
                      ),
                    ],
                  ),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (orderType == 'delivery')
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Address *',
                        border: OutlineInputBorder(),
                      ),
                    ),

                  const Divider(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text('\$${getSubtotal().toStringAsFixed(2)}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax (8.25%):'),
                      Text('\$${getTax().toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '\$${getTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),


                  if (Platform.isIOS)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.apple),
                      label: const Text('Pay with Apple Pay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: handlePaymentSheet,
                    ),
                ],
              ),
            ),
    );
  }
}
