import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mskn/home/models/property.dart';
import 'package:mskn/home/property_details.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Property>> _getFavoriteProperties() async* {
    if (userId == null) {
      yield [];
      return;
    }

    // أولًا نجيب IDs من المفضلة
    final favStream = FirebaseFirestore.instance
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .snapshots();

    await for (final snapshot in favStream) {
      final favIds = snapshot.docs.map((doc) => doc.id).toList();
      if (favIds.isEmpty) {
        yield [];
        continue;
      }

      // بعدين نجيب بياناتهم من كولكشن property
      final propSnap = await FirebaseFirestore.instance
          .collection('property')
          .where(FieldPath.documentId, whereIn: favIds)
          .get();

      yield propSnap.docs.map((doc) => Property.fromFirestore(doc)).toList();
    }
  }
    String formatPrice(String price) {
    final numeric = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '0';
    final number = double.tryParse(numeric) ?? 0;
    final formatted = number.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قائمة المفضلة'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
  
            const Divider(thickness: 1, height: 1),

            Expanded(
              child: StreamBuilder<List<Property>>(
                stream: _getFavoriteProperties(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ أثناء جلب المفضلات: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final properties = snapshot.data ?? [];

                  if (properties.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد عقارات مفضلة حاليًا.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: properties.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                      childAspectRatio: 0.70,
                    ),
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return GestureDetector(
                        onTap: () {
    showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent, // ضروري لخلفية شفافة
  builder: (context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // يلتقط الضغط في أي مكان فارغ
      onTap: () => Navigator.of(context).pop(), // يغلق الـ bottom sheet
      child: Stack(
        children: [
          // المحتوى الشفاف بالخلف (النقر عليه يغلق)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)), // يعطي ظل خفيف
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
                child: GestureDetector(
                  onTap: () {}, // يمنع الإغلاق عند النقر داخل المحتوى
                  child: FractionallySizedBox(
                    heightFactor: 0.9,
                    child: PropertyDetails(
                                    property: property,

                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
);

                  },
            child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
      
        ),
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
              side: BorderSide(
          color: Colors.grey.shade300, 
          width: 1, 
      ),
          ),
          elevation: 0,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Image.network(
                  property.image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          size: 40, color: Colors.grey),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10.w,
                  horizontal: 10.h
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location_name,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    // 💰 Price formatted with commas
                    Text(
                      '${formatPrice(property.price)} ر.س',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      ),
    );
  }
}
