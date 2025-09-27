import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mskn/home/add.dart';
import 'package:mskn/home/home.dart';
import 'package:mskn/home/map.dart';
import 'package:mskn/home/more.dart';
import 'package:mskn/main.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  StreamSubscription<User?>? _authStateSubscription;
  
  // Current selected index for bottom navigation
  int _selectedIndex = 0;
  
  // Pages to be displayed
  final List<Widget> _pages = [
    const HomeMainPage(),
    const MapPage(),
    const AddPage(),
    const AccountContent(),
    const MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
  
  void _checkAuthState() {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
      
      if (user == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      }
    });
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      extendBody: true,
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFF1A73E8),
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            iconSize: 24,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'الخريطة',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A73E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                label: 'إضافة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'الحساب',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz),
                label: 'أخرى',
              ),
            ],
          ),
        ),
      ),
    );
  }


}


class AccountContent extends StatelessWidget {
  const AccountContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'صفحة الحساب',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
