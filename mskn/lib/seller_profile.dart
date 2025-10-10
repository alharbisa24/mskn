import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_seller_profile.dart';

class SellerProfile extends StatelessWidget {
  const SellerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? _buildNotLoggedIn(context)
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('profile')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return _buildEmptyState(context);
                  }

                  final data = snapshot.data!.data() ?? {};
                  String _textOrNA(dynamic v) =>
                      (v == null || (v is String && v.trim().isEmpty))
                          ? 'غير متوفر'
                          : v.toString();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(context, title: 'الملف الشخصي للبائع'),
                        const SizedBox(height: 24),

                        // Header card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF111827).withOpacity(0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.storefront_outlined,
                                    color: Colors.blue, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _textOrNA(data['name']),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF111827),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'تعديل',
                                          icon: const Icon(Icons.edit,
                                              size: 20, color: Colors.blue),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EditSellerProfileScreen(
                                                        initialData: data),
                                              ),
                                            );
                                          },
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _textOrNA(data['email'] ?? user.email),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        _Section(title: 'المعلومات الأساسية', children: [
                          _InfoTile(
                            icon: Icons.person_outline,
                            label: 'الاسم',
                            value: _textOrNA(data['name']),
                          ),
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'البريد الإلكتروني',
                            value: _textOrNA(data['email'] ?? user.email),
                          ),
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'رقم الجوال',
                            value: _textOrNA(data['phone']),
                          ),
                        ]),

                        const SizedBox(height: 16),
                        _Section(title: 'الوثائق القانونية', children: [
                          _InfoTile(
                            icon: Icons.verified_user_outlined,
                            label: 'رقم الرخصة',
                            value: _textOrNA(data['license_number']),
                          ),
                          _InfoTile(
                            icon: Icons.event_available_outlined,
                            label: 'تاريخ إنشاء الرخصة',
                            value: _textOrNA(data['licence_created']),
                          ),
                          _InfoTile(
                            icon: Icons.event_busy_outlined,
                            label: 'تاريخ انتهاء الرخصة',
                            value: _textOrNA(data['licence_expired']),
                          ),
                        ]),

                        const SizedBox(height: 16),
                        _Section(title: 'روابط التواصل', children: [
                          _InfoTile(
                            icon: Icons.alternate_email,
                            label: 'تويتر',
                            value: _textOrNA(data['twitter']),
                          ),
                          _InfoTile(
                            icon: Icons.camera_alt_outlined,
                            label: 'انستقرام',
                            value: _textOrNA(data['instagram']),
                          ),
                          _InfoTile(
                            icon: Icons.chat_bubble_outline,
                            label: 'سناب شات',
                            value: _textOrNA(data['snapchat']),
                          ),
                        ]),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, {required String title}) {
    return Row(
      children: [
     
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context, title: 'الملف الشخصي'),
          const SizedBox(height: 40),
          const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'الرجاء تسجيل الدخول لعرض ملفك الشخصي',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context, title: 'الملف الشخصي'),
          const SizedBox(height: 40),
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'لم يتم العثور على بيانات الملف الشخصي. سيتم إنشاؤها تلقائياً بعد التسجيل.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
