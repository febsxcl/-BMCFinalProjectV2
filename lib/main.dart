import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ecommerce_app/screens/auth_wrapper.dart';
import 'package:ecommerce_app/providers/cart_provider.dart'; // 1. ADD THIS
import 'package:provider/provider.dart'; // 2. ADD THIS
import 'package:firebase_auth/firebase_auth.dart';


void main() async {
  // 1. Preserve the splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

    // 3. Set web persistence (Unchanged)
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // 4. --- THIS IS THE FIX ---
  // We manually create the CartProvider instance *before* runApp
  final cartProvider = CartProvider();
  
  // 5. We call our new initialize method *before* runApp
  cartProvider.initializeAuthListener();

  // 6. This is the old, buggy code we are replacing:
  /*
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(), // <-- This was the problem
      child: const MyApp(),
    ),
  );
  */
  
  // 7. This is the NEW code for runApp
  runApp(
    // 8. We use ChangeNotifierProvider.value
    ChangeNotifierProvider.value(
      value: cartProvider, // 9. We provide the instance we already created
      child: const MyApp(),
    ),
  );
  
  // 10. Remove splash screen (Unchanged)
  FlutterNativeSplash.remove();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Root of the app
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Comics & Manga Shop',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      // Show the auth wrapper to handle authentication state
      home: const AuthWrapper(),
    );
  }
}