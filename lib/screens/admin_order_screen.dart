import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // We'll use this for dates again

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  // 1. Get an instance of Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2. This is the function that updates the status in Firestore
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // 3. Find the document and update the 'status' field
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  // --- THIS IS THE FIXED FUNCTION ---
  // It now uses 'dialogContext' to pop, fixing the crash
  void _showStatusDialog(String orderId, String currentStatus) {
    showDialog(
      context: context, // This is the main screen's context
      
      // 1. RENAME this variable to 'dialogContext'
      builder: (dialogContext) { 
        const statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
        
        return AlertDialog(
          title: const Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) {
              return ListTile(
                title: Text(status),
                trailing: currentStatus == status ? const Icon(Icons.check) : null,
                onTap: () {
                  _updateOrderStatus(orderId, status);
                  // 2. FIX: Use 'dialogContext' to pop
                  Navigator.of(dialogContext).pop(); 
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              // 3. FIX: Use 'dialogContext' to pop here too
              onPressed: () => Navigator.of(dialogContext).pop(), 
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
      ),
      // 1. Use a StreamBuilder to get all orders
      body: StreamBuilder<QuerySnapshot>(
        // 2. This is our query
        stream: _firestore
            .collection('orders')
            .orderBy('createdAt', descending: true) // Newest first
            .snapshots(),
            
        builder: (context, snapshot) {
          // 3. Handle all states: loading, error, empty
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          // 4. We have the orders!
          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              
                // --- NULL-SAFE DATA HANDLING ---
              // This prevents crashes if data is missing
              final orderData = order.data() as Map<String, dynamic>;

              final Timestamp? timestamp = orderData['createdAt'];
              final String formattedDate = timestamp != null
                  ? DateFormat('MM/dd/yyyy hh:mm a').format(timestamp.toDate())
                  : 'No date';
              
              final String status = orderData['status'] ?? 'Unknown';
              final double totalPrice = (orderData['totalPrice'] ?? 0.0) as double;
              final String formattedTotal = '₱${totalPrice.toStringAsFixed(2)}';
              final String userId = orderData['userId'] ?? 'Unknown User';

              // 7. Build a Card for each order
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    'Order ID: ${order.id}', // Show the doc ID
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                    'User: ${orderData['userId']}\n'
                    'Total: ₱${(orderData['totalPrice']).toStringAsFixed(2)} | Date: $formattedDate'
                  ),
                  isThreeLine: true,
                  
                  // 8. Show the status with a colored chip
                  trailing: Chip(
                    label: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: 
                      status == 'Pending' ? Colors.orange : 
                      status == 'Processing' ? Colors.blue :
                      status == 'Shipped' ? Colors.deepPurple : 
                      status == 'Delivered' ? Colors.green : Colors.red,
                  ),
                  
                  // 9. On tap, show our update dialog
                  onTap: () {
                    _showStatusDialog(order.id, status);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
