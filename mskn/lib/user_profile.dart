import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mskn/main.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadProfile() {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection('profile').doc(uid).get();
  }

  Future<void> _updateProfile(Map<String, dynamic> data) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('profile')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _showEditDialog(Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(
        text: data['email'] ?? _auth.currentUser?.email ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('تعديل البيانات', textAlign: TextAlign.right),
          content: Form(
            key: formKey,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'البريد مطلوب';
                      final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!pattern.hasMatch(v.trim())) return 'بريد غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'رقم الجوال', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'رقم الجوال مطلوب'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF)),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final uid = _auth.currentUser!.uid;
      final newData = {
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
      };
      await _updateProfile(newData);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyApp()),
      (_) => false,
    );
  }

  Widget _infoLine(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue, size: 22),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text('لم يتم تسجيل الدخول')));

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        Map<String, dynamic> data = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data()!;
        } else {
          data = {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': '',
            'rank': 'user'
          };
          _updateProfile(data);
        }

        final name = (data['name'] as String?)?.trim() ??
            (user.displayName ?? 'بدون اسم');
        final email = (data['email'] as String?) ?? (user.email ?? 'بدون بريد');
        final phone = (data['phone'] as String?) ?? 'بدون رقم';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Text('الملف الشخصي',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                    
                
                ),

                // البطاقة العلوية
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                                color: const Color(0xFFE8F4FF),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.person,
                                color: Color(0xFF1A73E8), size: 34),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(email,
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // بطاقة المعلومات الأساسية
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text('المعلومات الأساسية',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 12),
                          _infoLine(
                              icon: Icons.person_outline,
                              label: 'الاسم',
                              value: name),
                          const Divider(),
                          _infoLine(
                              icon: Icons.email_outlined,
                              label: 'البريد الإلكتروني',
                              value: email),
                          const Divider(),
                          _infoLine(
                              icon: Icons.phone_android,
                              label: 'رقم الجوال',
                              value: phone),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // زر تعديل البيانات
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon:
                          const Icon(Icons.edit, color: Colors.white, size: 20),
                      label: const Text('تعديل البيانات',
                          style: TextStyle(color: Colors.white, fontSize: 17)),
                      onPressed: () => _showEditDialog(data),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // زر تسجيل الخروج
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 20),
                      label: const Text('تسجيل الخروج',
                          style: TextStyle(color: Colors.white, fontSize: 17)),
                      onPressed: _signOut,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
