import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ecommerce_app/screens/auth_wrapper.dart';
import 'package:ecommerce_app/providers/cart_provider.dart'; // 1. ADD THIS
import 'package:provider/provider.dart'; // 2. ADD THIS


void main() async {
  // 1. Preserve the splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Run the app
  runApp(
    // 2. We wrap our app in the provider
    ChangeNotifierProvider(
      // 3. This "creates" one instance of our cart
      create: (context) => CartProvider(),
      // 4. The child is our normal app
      child: const MyApp(),
    ),
  );

  // 4. Remove the splash screen
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