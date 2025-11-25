import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class DeleteSellersPage extends StatefulWidget {
  const DeleteSellersPage({super.key});

  @override
  State<DeleteSellersPage> createState() => _DeleteSellersPageState();
}

class _DeleteSellersPageState extends State<DeleteSellersPage> {
  // قائمة لتخزين الـ IDs الخاصة بالمسوقين المحددين
  Set<String> selectedUserIds = {};
  bool isSelectionMode = false;

  // متغيرات للتحقق من الصلاحية
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminPrivileges();
  }

  // التحقق من صلاحية الأدمن
  Future<void> _checkAdminPrivileges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('profile')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['rank'] == 'admin') {
          if (mounted) {
            setState(() {
              _isAdmin = true;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking admin status: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.rightSlide,
        title: 'غير مصرح',
        desc: 'عذراً، هذه الصفحة مخصصة للمشرفين فقط.',
        btnOkOnPress: () {
          Navigator.of(context).pop();
        },
        btnOkColor: Colors.red,
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2575FC)),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: Text("غير مصرح بالدخول")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'إدارة المسوقين',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedUserIds.clear();
                    isSelectionMode = false;
                  });
                },
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                label: const Text('إلغاء', style: TextStyle(color: Colors.red)),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          if (isSelectionMode)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'تم تحديد ${selectedUserIds.length} مسوق للحذف',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // جلب المسوقين (Seller أو Marketer)
              stream: FirebaseFirestore.instance
                  .collection('profile')
                  .where('rank', whereIn: ['seller', 'marketer'])
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF2575FC)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد مسوقين مسجلين حالياً',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final isSelected = selectedUserIds.contains(docId);

                    final name = data['name'] ?? 'بدون اسم';
                    final phone = data['phone'] ?? 'لا يوجد رقم';
                    final email = data['email'] ?? '';

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedUserIds.remove(docId);
                            if (selectedUserIds.isEmpty)
                              isSelectionMode = false;
                          } else {
                            selectedUserIds.add(docId);
                            isSelectionMode = true;
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F4FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF2575FC))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // الأيقونة (حقيبة للمسوق)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2575FC).withOpacity(0.2)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check
                                    : Icons.business_center,
                                color: isSelected
                                    ? const Color(0xFF2575FC)
                                    : Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // البيانات (اسم - ايميل - رقم - عدد عقارات)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // الاسم
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF2575FC)
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // عدد العقارات (الحل المضمون باستخدام get().docs.length)
                                  FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('property')
                                        .where('seller_id',
                                            isEqualTo:
                                                docId) // استخدام seller_id الصحيح
                                        .get(),
                                    builder: (context, propSnapshot) {
                                      String countText = '...';
                                      if (propSnapshot.hasData) {
                                        countText =
                                            '${propSnapshot.data!.docs.length} عقارات';
                                      }

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          countText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // الإيميل
                                  if (email.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.email_outlined,
                                              size: 14,
                                              color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // رقم الجوال
                                  Row(
                                    children: [
                                      Icon(Icons.phone_iphone,
                                          size: 14, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        phone,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontFamily: 'Arial',
                                        ),
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // دائرة الاختيار
                            if (isSelectionMode)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 10, top: 10),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? const Color(0xFF2575FC)
                                      : Colors.grey[300],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // زر الحذف العائم
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: Text(
                  'حذف المحدد (${selectedUserIds.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => _showDeleteConfirmationDialog(context),
              ),
            )
          : null,
    );
  }

  // نافذة التأكيد
  void _showDeleteConfirmationDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'تأكيد الحذف',
      desc:
          'هل أنت متأكد من حذف ${selectedUserIds.length} من المسوقين؟\nسيتم حذف حساباتهم ولكن قد تبقى عقاراتهم.',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await _deleteSelectedUsers();
      },
      btnOkText: 'نعم، حذف',
      btnCancelText: 'إلغاء',
      btnOkColor: Colors.red,
      btnCancelColor: Colors.grey,
    ).show();
  }

  // منطق الحذف
  Future<void> _deleteSelectedUsers() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String id in selectedUserIds) {
        DocumentReference userRef =
            FirebaseFirestore.instance.collection('profile').doc(id);
        batch.delete(userRef);
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        setState(() {
          selectedUserIds.clear();
          isSelectionMode = false;
        });

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'تم بنجاح',
          desc: 'تم حذف المسوقين المحددين بنجاح.',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'خطأ',
          desc: 'حدث خطأ غير متوقع: $e',
          btnOkOnPress: () {},
        ).show();
      }
    }
  }
}
