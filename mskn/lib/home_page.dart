import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mskn/home/add.dart';
import 'package:mskn/home/home.dart';
import 'package:mskn/home/map.dart';
import 'package:mskn/home/more.dart';
import 'package:mskn/home/property_details.dart';
import 'package:mskn/main.dart';
import 'dart:async';

import 'package:mskn/seller_profile.dart';
import 'package:mskn/user_profile.dart';

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
    AccountPageWrapper(),
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Color(0xFFFDFDFD),
            splashColor: Color(0xFFFDFDFD),
            highlightColor: Color(0xFFFDFDFD),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF1A73E8),
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
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
class AccountPageWrapper extends StatelessWidget {
  const AccountPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("لم يتم تسجيل الدخول"));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('profile')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("المستخدم غير موجود"));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final rank = data['rank'] ?? '';

        if (rank == 'seller') {
          return const SellerProfile();
        } else {
          return const UserProfile();
        }
      },
    );
  }
}
