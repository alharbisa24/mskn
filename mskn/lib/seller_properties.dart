import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class SellerPropertiesPage extends StatelessWidget {
  const SellerPropertiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عقاراتي'),
      ),
      body: SafeArea(
        child: user == null
            ? _buildNotLoggedIn()
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('property')
                    .where('seller_id', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'حدث خطأ أثناء تحميل العقارات',
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final String title = _firstNonEmpty([
                        data['title'],
                        data['name'],
                        'عقار بدون اسم',
                      ]);
                      final String subtitle = _composeSubtitle(data);

                      final String priceStr = _stringOrEmpty(data['price']);
                      final List<String> imageUrls =
                          _extractImageUrls(data['images']);
                      final String imageUrl =
                          imageUrls.isNotEmpty ? imageUrls.first : '';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF111827).withOpacity(0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isEmpty
                                  ? Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                      ),
                                      child: const Icon(
                                        Icons.home_outlined,
                                        color: Colors.blue,
                                      ),
                                    )
                                  : Image.network(
                                      imageUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 44,
                                          height: 44,
                                          color: Colors.blue.withOpacity(0.1),
                                          child: const Icon(
                                            Icons.home_outlined,
                                            color: Colors.blue,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                if (priceStr.isNotEmpty)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'السعر',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        priceStr,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            children: [
                              if (imageUrls.isNotEmpty)
                                _buildImagesRow(imageUrls),
                              const SizedBox(height: 12),
                              _buildDetailsSection(context, data),
                              const SizedBox(height: 12),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _confirmAndDelete(context, doc),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'حذف',
                                    style: TextStyle(color: Colors.red),
                                  ),
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
    );
  }

  Widget _buildNotLoggedIn() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'الرجاء تسجيل الدخول لعرض عقاراتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'لا توجد عقارات مسجلة حتى الآن',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      
    );
  }

  String _firstNonEmpty(List<dynamic> candidates) {
    for (final dynamic value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _composeSubtitle(Map<String, dynamic> data) {
    final List<String> parts = [];

    final String type = _stringOrEmpty(data['type']);
    if (type.isNotEmpty) parts.add('النوع: $type');

    final String rooms = _stringOrEmpty(data['rooms']);
    if (rooms.isNotEmpty) parts.add('الغرف: $rooms');

    final String bathrooms = _stringOrEmpty(data['bathrooms']);
    if (bathrooms.isNotEmpty) parts.add('الحمامات: $bathrooms');

    final String area = _stringOrEmpty(data['area']);
    if (area.isNotEmpty) parts.add('المساحة: $area م²');

    final String streetWidth = _stringOrEmpty(data['streetWidth']);
    if (streetWidth.isNotEmpty) parts.add('عرض الشارع: $streetWidth م');

    final String propertyAge = _stringOrEmpty(data['propertyAge']);
    if (propertyAge.isNotEmpty) parts.add('عمر العقار: $propertyAge');

    final String locationName = _stringOrEmpty(data['location_name']);
    if (locationName.isNotEmpty) parts.add('الموقع: $locationName');

    return parts.join(' • ');
  }

  Widget _buildDetailsSection(BuildContext context, Map<String, dynamic> data) {
    final String type = _stringOrEmpty(data['type']);
    final String rooms = _stringOrEmpty(data['rooms']);
    final String bathrooms = _stringOrEmpty(data['bathrooms']);
    final String area = _stringOrEmpty(data['area']);
    final String streetWidth = _stringOrEmpty(data['streetWidth']);
    final String propertyAge = _stringOrEmpty(data['propertyAge']);
    final String locationName = _stringOrEmpty(data['location_name']);

    final List<Widget> items = [];
    if (type.isNotEmpty)
      items.add(_detailChip(Icons.category_outlined, 'النوع', type));
    if (rooms.isNotEmpty)
      items.add(_detailChip(Icons.meeting_room_outlined, 'الغرف', rooms));
    if (bathrooms.isNotEmpty)
      items.add(_detailChip(Icons.bathtub_outlined, 'الحمامات', bathrooms));
    if (area.isNotEmpty)
      items.add(_detailChip(Icons.square_foot, 'المساحة', '$area م²'));
    if (streetWidth.isNotEmpty)
      items.add(_detailChip(Icons.straighten, 'عرض الشارع', '$streetWidth م'));
    if (propertyAge.isNotEmpty)
      items
          .add(_detailChip(Icons.schedule_outlined, 'عمر العقار', propertyAge));
    if (locationName.isNotEmpty) {
      items.add(
        _detailChip(
          Icons.place_outlined,
          'الموقع',
          locationName,
          // Constrain width so it wraps to approximately two lines
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      children: items,
    );
  }

  Widget _detailChip(IconData icon, String label, String value,
      {double? maxWidth}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? double.infinity,
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        ],
      ),
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: maxWidth + 56), // extra for icon/padding
        child: child,
      );
    }
    return child;
  }

  String _stringOrEmpty(dynamic value) {
    if (value == null) return '';
    final String s = value.toString().trim();
    return s;
  }

  String _extractFirstImageUrl(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final dynamic first = value.first;
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }
    return '';
  }

  List<String> _extractImageUrls(dynamic value) {
    final List<String> urls = [];
    if (value is List) {
      for (final dynamic v in value) {
        if (v is String && v.trim().isNotEmpty) {
          urls.add(v.trim());
        } else if (v is Map &&
            v['url'] is String &&
            (v['url'] as String).trim().isNotEmpty) {
          urls.add((v['url'] as String).trim());
        }
      }
    }
    return urls;
  }

  Widget _buildImagesRow(List<String> urls) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final String url = urls[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 140,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 140,
                  height: 100,
                  color: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.blue,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatCreatedAt(dynamic value) {
    if (value is Timestamp) {
      final DateTime dt = value.toDate();
      final String y = dt.year.toString().padLeft(4, '0');
      final String m = dt.month.toString().padLeft(2, '0');
      final String d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return _stringOrEmpty(value);
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String title = _firstNonEmpty([
      data['title'],
      data['name'],
      'عقار بدون اسم',
    ]);

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'تاكيد الحذف',
      desc: 'هل تريد حذف العقار "$title"؟ لا يمكن التراجع عن هذا الإجراء.',
      btnCancelText: 'إلغاء',
      btnOkText: 'حذف العقار',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await _deleteProperty(context, doc);
      },
      btnOkColor: Colors.red,
      btnCancelColor: Colors.grey,
    ).show();
  }

  Future<void> _deleteProperty(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = doc.data();
      final List<String> imageUrls = _extractImageUrls(data['images']);

      if (imageUrls.isNotEmpty) {
        for (String imageUrl in imageUrls) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            debugPrint('Error deleting image: $e');
          }
        }
      }

      final firestore = FirebaseFirestore.instance;
      final propertyId = doc.id;

      final propertyRef = firestore.collection('property').doc(propertyId);

      final favoritesRoots = await firestore.collection('favorites').get();
      final favoriteDocs = <DocumentReference<Map<String, dynamic>>>[];

      for (final userFavorites in favoritesRoots.docs) {
        final candidate =
            userFavorites.reference.collection('items').doc(propertyId);
        final candidateSnap = await candidate.get();
        if (candidateSnap.exists) {
          favoriteDocs.add(candidate);
        }
      }

      final reportsSnapshot = await firestore
          .collection('reports')
          .where('property_id', isEqualTo: propertyId)
          .get();

      final batch = firestore.batch();
      batch.delete(propertyRef);

      for (final favDoc in favoriteDocs) {
        batch.delete(favDoc);
      }

      for (final report in reportsSnapshot.docs) {
        batch.update(report.reference, {
          'status': 'resolved',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (navigator.canPop()) {
        navigator.pop();
      }

      if (!context.mounted) return;

      await AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: 'تم الحذف',
        desc: 'تم حذف العقار بنجاح.',
        btnOkText: 'حسناً',
        btnOkOnPress: () {},
        btnOkColor: Colors.green,
      ).show();
    } catch (error) {
      if (navigator.canPop()) {
        navigator.pop();
      }

      if (!context.mounted) return;

      await AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'تعذر الحذف',
        desc: 'حدث خطأ غير متوقع: $error',
        btnOkText: 'حسناً',
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
      ).show();
    }
  }
}
