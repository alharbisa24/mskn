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
import 'package:mskn/seller_properties.dart';

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
    // If "More" tab is tapped, show a mini popup (bottom sheet) instead of full page
    if (index == 4) {
      _showMoreSheet();
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.45,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.transparent),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF111827).withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SellerPropertiesPage(),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.home_work_outlined, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'عقاراتي',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
