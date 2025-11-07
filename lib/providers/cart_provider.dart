import 'dart:async'; // 1. ADD THIS (for StreamSubscription)
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 2. ADD THIS
import 'package:cloud_firestore/cloud_firestore.dart'; // 3. ADD THIS


// 1. A simple class to hold the data for an item in the cart
class CartItem {
  final String id;       // The unique product ID
  final String name;
  final double price;
  int quantity;        // Quantity can change, so it's not final

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1, // Default to 1 when added
  });

    // 1. ADD THIS: A method to convert our CartItem object into a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  // 2. ADD THIS: A factory constructor to create a CartItem from a Map
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
    );
  }
}


// 1. The CartProvider class "mixes in" ChangeNotifier
class CartProvider with ChangeNotifier {
  
  // 2. This is the private list of items.
  //    No one outside this class can access it directly.
  List<CartItem> _items = [];

  // 3. A public "getter" to let widgets *read* the list of items
  List<CartItem> get items => _items;

    // 5. ADD THESE: New properties for auth and database
  String? _userId; // Will hold the current user's ID
  StreamSubscription? _authSubscription; // To listen to auth changes
    // 6. ADD THESE: Get Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // 4. A public "getter" to calculate the total number of items
  int get itemCount {
    int total = 0;
    for (var item in _items) {
      total += item.quantity;
    }
    return total;
  }

  // 5. A public "getter" to calculate the total price
  double get totalPrice {
    double total = 0.0;
    for (var item in _items) {
      total += (item.price * item.quantity);
    }
    return total;
  }

   // 2. ADD this new EMPTY constructor.
  CartProvider() {
    print('CartProvider created.');
  }

  // 3. ADD this new PUBLIC method. We moved all the logic here.
  void initializeAuthListener() {
    print('CartProvider auth listener initialized');
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print('User logged out, clearing cart.');
        _userId = null;
        _items = []; 
      } else {
        print('User logged in: ${user.uid}. Fetching cart...');
        _userId = user.uid;
        _fetchCart(); 
      }
      notifyListeners();
    });
  }

  // 6. The main logic: "Add Item to Cart"
  void addItem(String id, String name, double price) {
    // 7. Check if the item is already in the cart
    var index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      // 8. If YES: just increase the quantity
      _items[index].quantity++;
    } else {
      // 9. If NO: add it to the list as a new item
      _items.add(CartItem(id: id, name: name, price: price));
    }

    // 10. CRITICAL: This tells all "listening" widgets to rebuild!
    _saveCart(); // 10. ADD THIS LINE
    notifyListeners();
  }

  // 11. The "Remove Item from Cart" logic
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveCart(); // 11. ADD THIS LINE
    notifyListeners(); // Tell widgets to rebuild
  }

  // 1. ADD THIS: Creates an order in the 'orders' collection
  Future<void> placeOrder() async {
    // 2. Check if we have a user and items
    if (_userId == null || _items.isEmpty) {
      // Don't place an order if cart is empty or user is logged out
      throw Exception('Cart is empty or user is not logged in.');
    }

    try {
      // 3. Convert our List<CartItem> to a List<Map> using toJson()
      final List<Map<String, dynamic>> cartData = 
          _items.map((item) => item.toJson()).toList();
      
      // 4. Get total price and item count from our getters
      final double total = totalPrice;
      final int count = itemCount;

      // 5. Create a new document in the 'orders' collection
      await _firestore.collection('orders').add({
        'userId': _userId,
        'items': cartData, // Our list of item maps
        'totalPrice': total,
        'itemCount': count,
        'status': 'Pending', // 6. IMPORTANT: For admin verification
        'createdAt': FieldValue.serverTimestamp(), // For sorting
      });
      
      // 7. Note: We DO NOT clear the cart here.
      //    We'll call clearCart() separately from the UI after this succeeds.
      
    } catch (e) {
      print('Error placing order: $e');
      // 8. Re-throw the error so the UI can catch it
      throw e; 
    }
  }

    // 9. ADD THIS: Clears the cart locally AND in Firestore
  Future<void> clearCart() async {
    // 10. Clear the local list
    _items = [];
    
    // 11. If logged in, clear the Firestore cart as well
    if (_userId != null) {
      try {
        // 12. Set the 'cartItems' field in their cart doc to an empty list
        await _firestore.collection('userCarts').doc(_userId).set({
          'cartItems': [],
        });
        print('Firestore cart cleared.');
      } catch (e) {
        print('Error clearing Firestore cart: $e');
      }
    }
    
    // 13. Notify all listeners (this will clear the UI)
    notifyListeners();
  }

   // 8. ADD THIS: Fetches the cart from Firestore
  Future<void> _fetchCart() async {
    if (_userId == null) return; // Not logged in, nothing to fetch

    try {
      // 1. Get the user's specific cart document
      final doc = await _firestore.collection('userCarts').doc(_userId).get();
      
      if (doc.exists && doc.data()!['cartItems'] != null) {
        // 2. Get the list of items from the document
        final List<dynamic> cartData = doc.data()!['cartItems'];
        
        // 3. Convert that list of Maps into our List<CartItem>
        //    (This is why we made CartItem.fromJson!)
        _items = cartData.map((item) => CartItem.fromJson(item)).toList();
        print('Cart fetched successfully: ${_items.length} items');
      } else {
        // 4. The user has no saved cart, start with an empty one
        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = []; // On error, default to an empty cart
    }
    notifyListeners(); // Update the UI
  }

  // 9. ADD THIS: Saves the current local cart to Firestore
  Future<void> _saveCart() async {
    if (_userId == null) return; // Not logged in, nowhere to save

    try {
      // 1. Convert our List<CartItem> into a List<Map>
      //    (This is why we made toJson()!)
      final List<Map<String, dynamic>> cartData = 
          _items.map((item) => item.toJson()).toList();
      
      // 2. Find the user's document and set the 'cartItems' field
      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
      print('Cart saved to Firestore');
    } catch (e) {
      print('Error saving cart: $e');
    }
  }
 // 12. ADD THIS METHOD (or update it if it exists)
  @override
  void dispose() {
    _authSubscription?.cancel(); // Cancel the auth listener
    super.dispose();
  }
}

