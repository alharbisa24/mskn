import 'dart:math';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mskn/home/advertiser_properties_page.dart';
import 'package:mskn/home/models/property.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class PropertyDetails extends StatefulWidget {
  final Property property;
  PropertyDetails({super.key, required this.property});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  int _currentImageIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  bool isFavorite = false;

  Map<String, dynamic>? sellerProfile;
  bool isLoading = true;
  bool _isAdmin = false;
  bool _isDeleting = false;

  late LatLng position;

  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  bool _isNeighborhoodAnalyzing = false;
  Map<String, dynamic>? _neighborhoodResult;

  @override
  void initState() {
    super.initState();

    position = LatLng(
      widget.property.location_coordinate.latitude,
      widget.property.location_coordinate.longitude,
    );

    _loadSeller();
    _checkIfFavorite(); 
    _loadAdminStatus();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(user.uid)
        .collection('items')
        .doc(widget.property.uid);

    final favSnap = await favRef.get();
    if (favSnap.exists) {
      setState(() {
        isFavorite = true;
      });
    }
  }

  Future<void> _loadSeller() async {
    final doc = await FirebaseFirestore.instance
        .collection('profile')
        .doc(widget.property.seller_id)
        .get();

    setState(() {
      sellerProfile = doc.data();
      isLoading = false;
    });
  }

  Future<void> _loadAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('profile')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) return;

      final rank = (profileDoc.data()?['rank'] ?? '').toString().toLowerCase();
      if (!mounted) return;
      setState(() {
        _isAdmin = rank == 'admin';
      });
    } catch (_) {
    }
  }

  Future<void> _confirmDeleteProperty() async {
    if (_isDeleting) return;

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'تاكيد الحذف',
      desc: 'هل تريد حذف العقار "${widget.property.title}"؟ لا يمكن التراجع عن هذا الإجراء.',
      btnCancelText: 'إلغاء',
      btnOkText: 'حذف العقار',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await _deleteProperty();
      },
      btnOkColor: Colors.red,
      btnCancelColor: Colors.grey
    ).show();
}

Future<void> _deleteProperty() async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    // عرض اللودر
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // حذف الصور من Storage
      if (widget.property.images.isNotEmpty) {
        for (String imageUrl in widget.property.images) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            print('Error deleting image: $e');
          }
        }
      }

      final firestore = FirebaseFirestore.instance;
      final propertyId = widget.property.uid;
      final propertyRef = firestore.collection('property').doc(propertyId);

      final favoritesRoots = await firestore.collection('favorites').get();
      final favoriteDocs = <DocumentReference<Map<String, dynamic>>>[];

      for (final userFavorites in favoritesRoots.docs) {
        final candidate = userFavorites.reference.collection('items').doc(propertyId);
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

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); 
      }

      if (!mounted) return;

      await AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: 'تم الحذف',
        desc: 'تم حذف العقار بنجاح.',
        btnOkText: 'حسناً',
        btnOkOnPress: () {
          Navigator.of(context).pop();
        },
        btnOkColor: Colors.green,
      ).show();

    } catch (error) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); 
      }

      if (!mounted) return;

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
      
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _analyzeProperty() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final apiKey = dotenv.get('GEMINI_API_KEY');
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final landmarks = {
        'جامعة الملك سعود': LatLng(24.7241, 46.6215),
        'جامعة الامام محمد بن سعود': LatLng(24.8169, 46.7106),
        'KAFD': LatLng(24.7697, 46.6405),
        'المدينة الرقمية': LatLng(24.741130, 46.635813),
      };

      final distances = <String, double>{};
      for (final entry in landmarks.entries) {
        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          entry.value.latitude,
          entry.value.longitude,
        );
        distances[entry.key] = distance;
      }

      final prompt = '''
قم بتحليل هذا العقار بالتفصيل:

معلومات العقار:
- العنوان: ${widget.property.title}
- النوع: ${widget.property.type}
- طريقة الشراء: ${widget.property.purchaseType.arabic}
- السعر: ${widget.property.price} ريال
- الموقع: ${widget.property.location_name}
- عدد الغرف: ${widget.property.rooms}
- عدد الحمامات: ${widget.property.bathrooms}
- المساحة: ${widget.property.area} متر مربع
- عرض الشارع: ${widget.property.streetWidth} متر
- عمر العقار: ${widget.property.propertyAge} سنة
- الوصف: ${widget.property.description}

المسافات إلى المعالم الرئيسية:
${distances.entries.map((e) => '- ${e.key}: ${e.value.toStringAsFixed(1)} كم').join('\n')}

يرجى تقديم التحليل بصيغة JSON فقط بالشكل التالي:
{
  "strengths": ["نقطة قوة 1", "نقطة قوة 2", "نقطة قوة 3"],
  "weaknesses": ["نقطة ضعف 1", "نقطة ضعف 2"],
  "target_audience": "الفئة المستهدفة",
  "price_assessment": {
    "verdict": "عادل/مرتفع/منخفض",
    "explanation": "شرح مختصر"
  },
  "fraud_risk": {
    "percentage": 15,
    "reason": "سبب التقييم"
  },
  "recommendation": "توصية نهائية"
}

ملاحظة: استخدم اللغة العربية فقط وكن دقيقاً في التحليل.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      print(response);
      
      if (response.text == null) {
        throw Exception('No response from AI');
      }

      String jsonStr = response.text!;
      jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final analysis = json.decode(jsonStr);
      analysis['distances'] = distances;

      setState(() {
        _analysisResult = analysis;
        _isAnalyzing = false;
      });

      _showAnalysisBottomSheet();
    } catch (e) {
      setState(() => _isAnalyzing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحليل العقار: $e')),
      );
    }
  }

  Future<void> _analyzeNeighborhood() async {
    setState(() => _isNeighborhoodAnalyzing = true);

    try {
      final apiKey = dotenv.get('GEMINI_API_KEY');
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt = '''
قم بتحليل الحي التالي بشكل احترافي وحديث:
- اسم الحي: ${widget.property.location_name}
- المدينة: الرياض، السعودية

المطلوب بصيغة JSON فقط:
{
  "services_proximity": {
    "schools": "قريب/متوسط/بعيد + وصف مختصر",
    "hospitals": "قريب/متوسط/بعيد + وصف مختصر",
    "shopping": "قريب/متوسط/بعيد + وصف مختصر",
    "transport": "قريب/متوسط/بعيد + وصف مختصر"
  },
  "average_price_per_sqm": {
    "value": 0000,
    "confidence": "عالي/متوسط/منخفض",
    "explanation": "شرح مختصر"
  },
  "five_year_forecast": {
    "trend": "ارتفاع/ثبات/انخفاض",
    "reasons": ["سبب 1", "سبب 2", "سبب 3"],
    "expected_change_percentage": 0
  },
  "neighborhood_details": [
    "تفصيل 1",
    "تفصيل 2",
    "تفصيل 3"
  ],
  "summary": "خلاصة مختصرة باللغة العربية"
}

ملاحظات:
- استخدم اللغة العربية فقط.
- إن لم تتوفر بيانات دقيقة، قدم تقديرات مع توضيح مستوى الثقة.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text == null) throw Exception('لا يوجد رد من الذكاء الاصطناعي');

      String jsonStr = response.text!;
      jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = json.decode(jsonStr);

      setState(() {
        _neighborhoodResult = parsed;
        _isNeighborhoodAnalyzing = false;
      });

      _showNeighborhoodAnalysisSheet();
    } catch (e) {
      setState(() => _isNeighborhoodAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحليل الحي: $e')),
      );
    }
  }

  void _showNeighborhoodAnalysisSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.apartment, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تحليل ذكي للحي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(widget.property.location_name, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildServicesProximityCard(),
                    const SizedBox(height: 16),
                    _buildAvgPriceCard(),
                    const SizedBox(height: 16),
                    _buildForecastCard(),
                    const SizedBox(height: 16),
                    _buildNeighborhoodDetailsCard(),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageGallery(
          images: List<String>.from(widget.property.images),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildServicesProximityCard() {
    final s = _neighborhoodResult?['services_proximity'] ?? {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.room_preferences_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text('القرب من الخدمات والمدارس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          ]),
          const SizedBox(height: 12),
          _serviceRow('المدارس', s['schools']),
          _serviceRow('المستشفيات', s['hospitals']),
          _serviceRow('التسوق', s['shopping']),
          _serviceRow('المواصلات', s['transport']),
        ],
      ),
    );
  }

  Widget _serviceRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(
              '${value ?? 'غير متوفر'}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvgPriceCard() {
    final avg = _neighborhoodResult?['average_price_per_sqm'] ?? {};
    final value = (avg['value'] ?? 0).toString();
    final conf = (avg['confidence'] ?? 'غير محدد').toString();
    final exp = (avg['explanation'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.price_change_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('متوسط سعر المتر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('$value ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('الثقة: $conf', style: const TextStyle(color: Colors.indigo)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(exp, style: const TextStyle(fontSize: 14)),
      ]),
    );
  }

  Widget _buildForecastCard() {
    final f = _neighborhoodResult?['five_year_forecast'] ?? {};
    final trend = (f['trend'] ?? '').toString();
    final reasons = List<String>.from(f['reasons'] ?? []);
    final percent = (f['expected_change_percentage'] ?? 0).toString();
    Color color = trend.contains('ارتفاع') ? Colors.green : trend.contains('انخفاض') ? Colors.red : Colors.orange;
    IconData icon = trend.contains('ارتفاع') ? Icons.trending_up : trend.contains('انخفاض') ? Icons.trending_down : Icons.remove;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text('توقع ٥ سنوات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('الاتجاه: $trend • ${percent}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ]),
        const SizedBox(height: 10),
        ...reasons.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(r, style: const TextStyle(fontSize: 14))),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _buildNeighborhoodDetailsCard() {
    final details = List<String>.from(_neighborhoodResult?['neighborhood_details'] ?? []);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.info_outline, color: Colors.blueGrey),
          SizedBox(width: 8),
          Text('تفاصيل الحي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ]),
        const SizedBox(height: 12),
        ...details.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(d)),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _buildSummaryCard() {
    final summary = (_neighborhoodResult?['summary'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.summarize_outlined, color: Colors.white),
          SizedBox(width: 8),
          Text('الخلاصة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const SizedBox(height: 8),
        Text(
        summary,
        style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
        ),
      ]),
    );
  }


  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _showAnalysisBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تحليل العقار بالذكاء الاصطناعي',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Strengths
                    _buildAnalysisSection(
                      title: 'نقاط القوة',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      items: List<String>.from(_analysisResult?['strengths'] ?? []),
                    ),

                    const SizedBox(height: 20),

                    // Weaknesses
                    _buildAnalysisSection(
                      title: 'نقاط الضعف',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      items: List<String>.from(_analysisResult?['weaknesses'] ?? []),
                    ),

                    const SizedBox(height: 20),

                    // Target Audience
                    _buildInfoCard(
                      title: 'الفئة المستهدفة',
                      icon: Icons.people_outline,
                      color: Colors.purple,
                      content: _analysisResult?['target_audience'] ?? '',
                    ),

                    const SizedBox(height: 20),

                    // Price Assessment
                    _buildPriceAssessmentCard(),

                    const SizedBox(height: 20),

                    // Fraud Risk
                    _buildFraudRiskCard(),

                    const SizedBox(height: 20),

                    // Distances
                    _buildDistancesCard(),

                    const SizedBox(height: 20),

                    // Recommendation
                    _buildRecommendationCard(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAssessmentCard() {
    final assessment = _analysisResult?['price_assessment'];
    final verdict = assessment?['verdict'] ?? '';
    
    Color color;
    IconData icon;
    
    if (verdict.contains('عادل')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (verdict.contains('مرتفع')) {
      color = Colors.red;
      icon = Icons.arrow_upward;
    } else {
      color = Colors.blue;
      icon = Icons.arrow_downward;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                'تقييم السعر',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      verdict,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            assessment?['explanation'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraudRiskCard() {
    final fraudRisk = _analysisResult?['fraud_risk'];
    final percentage = fraudRisk?['percentage'] ?? 0;
    
    Color color;
    String riskLevel;
    
    if (percentage < 20) {
      color = Colors.green;
      riskLevel = 'منخفضة';
    } else if (percentage < 50) {
      color = Colors.orange;
      riskLevel = 'متوسطة';
    } else {
      color = Colors.red;
      riskLevel = 'مرتفعة';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                'تقييم الاحتيال',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة الخطورة: $riskLevel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fraudRisk?['reason'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistancesCard() {
    final distances = _analysisResult?['distances'] as Map<String, dynamic>?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.place_outlined, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'المسافات للمعالم الرئيسية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...distances!.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${entry.value.toStringAsFixed(1)} كم',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.recommend_outlined, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'التوصية النهائية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _analysisResult?['recommendation'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true, 
              floating: true,
              snap:
                  true,
              expandedHeight: 0, 
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.6), 
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.6),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.black87,
                      ),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('يجب تسجيل الدخول لإضافة المفضلة')),
                          );
                          return;
                        }

                        final favRef = FirebaseFirestore.instance
                            .collection('favorites')
                            .doc(user.uid)
                            .collection('items')
                            .doc(widget.property.uid);

                        final doc = await favRef.get();

                        if (doc.exists) {
                          await favRef.delete();
                          setState(() => isFavorite = false);
                           AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: 'تمت الازاله',
        desc: 'تمت ازاله العقار من المفضلة بنجاح',
        btnOkText: 'حسناً',
        btnOkOnPress: () {},
        btnOkColor: Colors.blueAccent,
      ).show();
                        } else {
                          await favRef.set({
                            'added_at': FieldValue.serverTimestamp(),
                          });
                          setState(() => isFavorite = true);
                                                 AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: 'تمت الاضافة',
        desc: 'تمت اضافة العقار لقائمة المفضلة بنجاح',
        btnOkText: 'حسناً',
        btnOkOnPress: () {},
        btnOkColor: Colors.blueAccent,
      ).show();
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.6),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.black87),
                      onPressed: () {
                        final String shareText = '''
مرحبًا! هذا العقار متاح في تطبيق مسكن !


الاسم: ${widget.property.title}
النوع: ${widget.property.type}
نوع البيع: ${widget.property.purchaseType}
المبلغ: ${widget.property.price} ريال
الموقع: ${widget.property.location_name}
عدد الغرف: ${widget.property.rooms}
عدد الحمامات: ${widget.property.bathrooms}
عمر العقار: ${widget.property.propertyAge}
المساحة: ${widget.property.area} م²

للمزيد من التفاصيل، حمل تطبيق مسكن!
''';
 
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;

                        Share.share(
                          shareText,
                          sharePositionOrigin:
                              box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                    ),
                  ),
                ),
if (_isAdmin || widget.property.seller_id == FirebaseAuth.instance.currentUser?.uid)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.6),
                      child: IconButton(
                        tooltip: 'حذف العقار',
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: _isDeleting ? null : _confirmDeleteProperty,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.6),
                    child: IconButton(
                      icon: const Icon(Icons.flag_outlined,
                          color: Colors.black87),
                      onPressed: () => _showReportDialog(context),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CarouselSlider(
                        carouselController: _carouselController,
                        options: CarouselOptions(
                          height: 300,
                          viewportFraction: 1.0,
                          enlargeCenterPage: false,
                          onPageChanged: (index, reason) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          autoPlay: false,
                        ),
                        items: widget.property.images.map<Widget>((imageUrl) {
                          final index = widget.property.images.indexOf(imageUrl);
                          return Builder(
                            builder: (BuildContext context) {
                              return GestureDetector(
                                onTap: () => _showFullScreenImage(index),
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${widget.property.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.4),
                            child: const Icon(Icons.chevron_right,
                                color: Colors.white),
                          ),
                          onPressed: () {
                            _carouselController.nextPage();
                          },
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.4),
                            child: const Icon(Icons.chevron_left,
                                color: Colors.white),
                          ),
                          onPressed: () {
                            _carouselController.previousPage();
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  widget.property.title,
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${widget.property.price} ريال',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A73E8),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A73E8)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.property.purchaseType.arabic,
                                    style: const TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        Container(
                          margin: EdgeInsets.only(bottom: 16.h),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6A11CB).withOpacity(0.05),
                                const Color(0xFF2575FC).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2575FC).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'الموقع',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.property.location_name,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isNeighborhoodAnalyzing ? null : _analyzeNeighborhood,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2575FC).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _isNeighborhoodAnalyzing
                                        ? const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'جاري التحليل...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'تحليل الحي بالذكاء الاصطناعي',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Icon(
                                                Icons.auto_awesome,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24.h),

                        _buildKeyFeatures(),

                        SizedBox(height: 24.h),

            

                        Text(
                          'وصف العقار',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          widget.property.description,
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.grey[700],
                          ),
                        ),

                        SizedBox(height: 24.h),



                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2575FC).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isAnalyzing ? null : _analyzeProperty,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: _isAnalyzing
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                         
                                            Text(
                                              'جاري التحليل...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                     SizedBox(width: 12),
                                               SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'تحليل العقار بالذكاء الاصطناعي',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                      SizedBox(width: 12),
                                  Icon(Icons.analytics, color: Colors.white, size: 24),

                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                                _buildMapView(),

                    
                    SizedBox(height: 24.h),
                        _buildLicenseDetails(),

                          SizedBox(height: 24.h),

                        _buildSellerDetails(),


                        SizedBox(
                          height: 50.h,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -3),
                blurRadius: 10,
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 25.h, vertical: 12.w),
          child: isLoading
              ? const ButtonsShimmer()
              : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedWhatsapp, size: 18),
                        label: const Text('واتساب'),
                        onPressed: () {
                          final phoneNumber = sellerProfile?['phone'] ?? '';
                          launchUrl(Uri.parse('https://wa.me/$phoneNumber'));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('اتصال'),
                        onPressed: () {
                          final phoneNumber = sellerProfile?['phone'] ?? '';
                          launchUrl(Uri.parse('tel:$phoneNumber'));
                        },
                      ),
                    ),
                  ],
                )),
    );
  }

  Widget _buildKeyFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: _buildKeyFeatureItem(
                      Icons.king_bed_outlined, '${widget.property.rooms} غرف')),
             if(widget.property.bathrooms != '')
              Expanded(
                  child: _buildKeyFeatureItem(Icons.bathtub_outlined,
                      '${widget.property.bathrooms} حمامات')),
              Expanded(
                  child: _buildKeyFeatureItem(Icons.square_foot_outlined,
                      '${widget.property.area} م²')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: _buildKeyFeatureItem(Icons.straighten_outlined,
                      '${widget.property.streetWidth} م')),
              Expanded(
                  child: _buildKeyFeatureItem(
                      Icons.calendar_month, '${widget.property.propertyAge} سنين')),
              Expanded(
                  child: _buildKeyFeatureItem(
                      Icons.category, '${widget.property.type}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[700], size: 22),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الموقع',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: GoogleMap(
              key: ValueKey('property_map_${widget.property.uid}'),
              initialCameraPosition: CameraPosition(
                target: position,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('property'),
                  position: position,
                  infoWindow: InfoWindow(title: widget.property.title),
                ),
              },
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: Color(0xFF1A73E8), size: 20),
              SizedBox(width: 8),
              Text(
                'بيانات ترخيص الاعلان',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الترخيص',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.property.licence_number,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellerDetails() {
    if (isLoading || sellerProfile == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: 100,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 60,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                  height: 12,
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              Container(
                  height: 12,
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 40, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final String sellerInitials = (sellerProfile?['name'] ?? 'مستخدم')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();

    final bool isSeller = sellerProfile?['rank'] == 'seller';

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF1A73E8),
                  child: Text(
                    sellerInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerProfile?['name'] ?? 'مستخدم',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSeller
                                  ? const Color(0xFF1A73E8).withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isSeller ? 'بائع' : 'مستخدم ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSeller
                                    ? const Color(0xFF1A73E8)
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                GestureDetector(
                  onTap: (){
                         Navigator.of(context).push(
                           MaterialPageRoute(
                    builder: (_) => AdvertiserPropertiesPage(
                      advertiserId: widget.property.seller_id ?? '',
                      advertiserName: sellerProfile?['name'] ?? 'مستخدم',
                    ),
                          )
                         );
                  
                  },
                  child: Row(
                    children: [
                      Text("عرض المزيد", style: TextStyle(
                        color: Colors.blueAccent
                      ),),
                      SizedBox(
                        width: 4,
                      ),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blueAccent
                      ),
                    ],
                  ),
                )
                
              ],
            ),
  
            if (isSeller) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رقم رخصة الوساطة العقارية',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sellerProfile?['license_number'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تاريخ انتهاء الرخصة',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sellerProfile?['licence_expired'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            SizedBox(height: 16.h),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedWhatsapp, size: 18),
                      label: const Text('واتساب'),
                      onPressed: () {
                        final phoneNumber = sellerProfile?['phone'] ?? '';
                        launchUrl(Uri.parse('https://wa.me/$phoneNumber'));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('اتصال'),
                      onPressed: () {
                        final phoneNumber = sellerProfile?['phone'] ?? '';
                        launchUrl(Uri.parse('tel:$phoneNumber'));
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.black,
                  radius: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedNewTwitter,
                        color: Colors.white,
                        size: 18),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          'https://x.com/${sellerProfile?['x']}'));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFE1306C),
                  radius: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedInstagram,
                        color: Colors.white,
                        size: 18),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          'https://instagram.com/${sellerProfile?['instagram']}'));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFFC00),
                  radius: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedSnapchat,
                        color: Colors.black,
                        size: 18),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          'https://snapchat.com/add/${sellerProfile?['snapchat']}'));
                    },
                  ),
                ),
              ],
            )
          ],
        ));
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReportType;
    final TextEditingController commentController = TextEditingController();

    final List<Map<String, dynamic>> reportTypes = [
      {
        'value': 'fake_property',
        'label': 'عقار وهمي',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
      },
      {
        'value': 'wrong_info',
        'label': 'معلومات خاطئة',
        'icon': Icons.info_outline,
        'color': Colors.blue,
      },
      {
        'value': 'spam',
        'label': 'إعلان مزعج',
        'icon': Icons.block,
        'color': Colors.red,
      },
      {
        'value': 'inappropriate',
        'label': 'محتوى غير لائق',
        'icon': Icons.report_outlined,
        'color': Colors.purple,
      },
      {
        'value': 'other',
        'label': 'أخرى',
        'icon': Icons.more_horiz,
        'color': Colors.grey,
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.flag,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الإبلاغ عن مشكلة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'نوع البلاغ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...reportTypes.map((type) {
                        final isSelected = selectedReportType == type['value'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedReportType = type['value'];
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? type['color'].withOpacity(0.1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? type['color']
                                      : Colors.grey[200]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: type['color'].withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      type['icon'],
                                      color: type['color'],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      type['label'],
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? type['color']
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: type['color'],
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 20),

                      const Text(
                        'تفاصيل إضافية (اختياري)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'أخبرنا المزيد عن المشكلة...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF2575FC),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedReportType == null
                                  ? null
                                  : () async {
                                      await _submitReport(
                                        dialogContext,
                                        selectedReportType!,
                                        commentController.text.trim(),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: const Text(
                                'ارسال البلاغ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(
    BuildContext dialogContext,
    String reportType,
    String comment,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب تسجيل الدخول للإبلاغ')),
          );
        }
        return;
      }

      // Show loading indicator
      if (dialogContext.mounted) {
        showDialog(
          context: dialogContext,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2575FC),
            ),
          ),
        );
      }

      // Submit report to Firebase
      await FirebaseFirestore.instance.collection('reports').add({
        'property_id': widget.property.uid,
        'property_title': widget.property.title,
        'reporter_id': user.uid,
        'report_type': reportType,
        'comment': comment.isEmpty ? null : comment,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Close loading dialog
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
        // Close report dialog
        Navigator.of(dialogContext).pop();
      }

      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'تم ارسال البلاغ بنجاح',
          desc: 'سيتم مراجعة البلاغ من قبلنا',
          btnOkText: 'حسناً',
          btnOkOnPress: () {},
          btnOkColor: Colors.green,
        ).show();
      }
    } catch (e) {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
        Navigator.of(dialogContext).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }
}

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 64,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                   
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.images[index],
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              opacity: isSelected
                                  ? const AlwaysStoppedAnimation(1.0)
                                  : const AlwaysStoppedAnimation(0.5),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

         
        ],
      ),
    );
  }
}

class ButtonsShimmer extends StatelessWidget {
  const ButtonsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}