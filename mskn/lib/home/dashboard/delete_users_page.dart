import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class DeleteUsersPage extends StatefulWidget {
  const DeleteUsersPage({super.key});

  @override
  State<DeleteUsersPage> createState() => _DeleteUsersPageState();
}

class _DeleteUsersPageState extends State<DeleteUsersPage> {
  // قائمة لتخزين الـ IDs الخاصة بالمستخدمين المحددين
  Set<String> selectedUserIds = {};
  bool isSelectionMode = false;

  // متغيرات للتحقق من الصلاحية (حماية الصفحة)
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminPrivileges();
  }

  // دالة "نقطة التفتيش": تتحقق هل المستخدم أدمن أم لا
  Future<void> _checkAdminPrivileges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('profile')
            .doc(user.uid)
            .get();

        // هنا الشرط: هل الرتبة أدمن؟
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

    // إذا وصل هنا، فهو ليس أدمن أو حدث خطأ
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
      // إظهار رسالة وطرد المستخدم
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
    // 1. حالة التحقق (Loading)
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2575FC)),
        ),
      );
    }

    // 2. حالة الطرد (Access Denied)
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: Text("غير مصرح بالدخول")),
      );
    }

    // 3. حالة الأدمن (الصفحة الطبيعية)
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'إدارة المستخدمين',
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
          // شريط معلومات يظهر عند التحديد
          if (isSelectionMode)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'تم تحديد ${selectedUserIds.length} مستخدم للحذف',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // --- التعديل هنا: البحث عن user و buyer معاً ---
              stream: FirebaseFirestore.instance
                  .collection('profile')
                  .where('rank', whereIn: ['user', 'buyer'])
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
                        Icon(Icons.people_outline,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد عملاء مسجلين حالياً',
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
                          children: [
                            // الأيقونة
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2575FC).withOpacity(0.2)
                                    : const Color(0xFF2575FC).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : Icons.person_outline,
                                color: const Color(0xFF2575FC),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // البيانات
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF2575FC)
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                      fontFamily: 'Arial',
                                    ),
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ),
                            ),

                            // دائرة الاختيار
                            if (isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
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

      // --- زر الحذف العائم ---
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
          'هل أنت متأكد من حذف ${selectedUserIds.length} من العملاء؟\nلا يمكن التراجع عن هذا الإجراء.',
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
        Navigator.pop(context); // إخفاء Loading
        setState(() {
          selectedUserIds.clear();
          isSelectionMode = false;
        });

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'تم بنجاح',
          desc: 'تم حذف العملاء المحددين بنجاح.',
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
