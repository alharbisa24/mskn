import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mskn/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mskn/register_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسكن',
      locale: Locale('ar'), 
      theme: ThemeData(
    textTheme: GoogleFonts.tajawalTextTheme(
      Theme.of(context).textTheme,
    ),
          ),
          
      home: const MyHomePage(),
        builder: (context, child) {
    return Directionality(
      textDirection: TextDirection.rtl, 
      child: child!,
    );
        }
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("مسكن"),
            ElevatedButton(onPressed: (){

            }, child: Text("تسجيل الدخول")),
            ElevatedButton(onPressed: (){
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => RegisterMenu()));

            }, child: Text("انشاء حساب"))

          ],
        ),
      )
    );
 
    
  }
}
