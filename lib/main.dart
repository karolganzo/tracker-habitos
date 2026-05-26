import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navegacion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AppHabitos());
}

class AppHabitos extends StatelessWidget {
  const AppHabitos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Hábitos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5C518),
          brightness: Brightness.dark,
        ),
      ),
      home: const Navegacion(),
    );
  }
}