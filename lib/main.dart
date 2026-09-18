import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WorkLifeApp());
}

class WorkLifeApp extends StatelessWidget {
  const WorkLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WorkLife',
        home: Scaffold(
          appBar: AppBar(
            title: const Text('WorkLife'),
          ),
          body: const Center(
            child: Text('WorkLife foundation ready!'),
          ),
        ),
      ),
    );
  }
}