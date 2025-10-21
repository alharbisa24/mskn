import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // عنوان الصفحة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'قائمة المفضلة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
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
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).pop(),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                          color: Colors.black.withOpacity(0.3)),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(25)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(25)),
                                          child: GestureDetector(
                                            onTap: () {},
                                            child: FractionallySizedBox(
                                              heightFactor: 0.9,
                                              child: PropertyDetails(
                                                  property: property),
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
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                          elevation: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Image.network(
                                  property.image,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
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
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      property.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      property.location_name,
                                      style:
                                          const TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.right,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${property.price} ر.س',
                                      style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
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
      ),
    );
  }
}
