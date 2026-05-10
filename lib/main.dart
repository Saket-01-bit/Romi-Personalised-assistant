import 'package:flutter/material.dart';
import 'package:romeo/home_page.dart';
import 'package:romeo/pallete.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Romi',

      theme: ThemeData.light(useMaterial3: true).copyWith(
        appBarTheme: const AppBarTheme(backgroundColor: Pallete.whiteColor),
          scaffoldBackgroundColor: Pallete.whiteColor),
      home: const HomePage(),
    );
  }
}