import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mskn/home/models/property.dart';
import 'package:mskn/home/property_details.dart';

final Dio _dio = Dio();

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(24.7136, 46.6753),
    zoom: 12,
  );

  late GoogleMapController _mapController;
  final Set<Circle> _districts = {};
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final NumberFormat _decimalPriceFormat = NumberFormat.decimalPattern('ar');

  final Map<String, BitmapDescriptor> _markerIconCache = {};
  final Map<String, String> _markerIconSignatures = {};
  StreamSubscription<Set<Marker>>? _markerSubscription;
  bool _hasShownMarkerError = false;

  Future<BitmapDescriptor> _createMarkerIcon(Property property) async {
    const double horizontalPadding = 12;
    const double pointerHeight = 18;
    const double minWidth = 84;

    final String priceLabel = '${_formatPriceDisplay(property.price)} ر.س';

    final TextPainter pricePainter = TextPainter(
      text: TextSpan(
        text: priceLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout();

    final double bubbleWidth = pricePainter.width + (horizontalPadding * 2);
    final double width = bubbleWidth < minWidth ? minWidth : bubbleWidth;
    final double bubbleHeight = pricePainter.height + 16;
    final double totalHeight = bubbleHeight + pointerHeight;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, bubbleHeight),
      const Radius.circular(20),
    );

    // Shadow for bubble.
    canvas.drawRRect(bubbleRect.shift(const Offset(0, 3)), shadowPaint);

    // Shadow for pointer.
    final Path pointerShadow = Path()
      ..moveTo(width / 2 - 12, bubbleHeight)
      ..lineTo(width / 2, bubbleHeight + pointerHeight)
      ..lineTo(width / 2 + 12, bubbleHeight)
      ..close();
    canvas.drawPath(pointerShadow.shift(const Offset(0, 3)), shadowPaint);

    final Color markerColor = _markerColor(property);
    final Paint fillPaint = Paint()..color = markerColor;

    // Marker bubble.
    canvas.drawRRect(bubbleRect, fillPaint);

    // Pointer triangle.
    final Path pointer = Path()
      ..moveTo(width / 2 - 12, bubbleHeight)
      ..lineTo(width / 2, bubbleHeight + pointerHeight)
      ..lineTo(width / 2 + 12, bubbleHeight)
      ..close();
    canvas.drawPath(pointer, fillPaint);

    // Price text centered inside bubble.
    final double textX = (width - pricePainter.width) / 2;
    final double textY = (bubbleHeight - pricePainter.height) / 2;
    pricePainter.paint(canvas, Offset(textX, textY));

    final ui.Image markerImage = await recorder.endRecording().toImage(
          width.ceil(),
          totalHeight.ceil(),
        );
    final ByteData? byteData =
        await markerImage.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Color _markerColor(Property property) {
    switch (property.purchaseType) {
      case PropertyPurchaseType.sell:
        return const Color(0xFF2575FC);
      case PropertyPurchaseType.rent:
        return const Color(0xFF34A853);
      case PropertyPurchaseType.other:
        break;
    }

    final String type = property.type.trim().toLowerCase();
    if (type.contains('فيلا') || type.contains('villa')) {
      return const Color(0xFF6A11CB);
    }
    if (type.contains('شقة') || type.contains('apartment')) {
      return const Color(0xFFFB8C00);
    }
    return const Color(0xFF1A73E8);
  }




  int _parseNumericValue(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatPriceDisplay(String raw) {
    final value = _parseNumericValue(raw);
    if (value == 0) {
      return raw.isNotEmpty ? raw : '0';
    }
    return _decimalPriceFormat.format(value);
  }

  void _listenToPropertyUpdates() {
    _markerSubscription?.cancel();
    _hasShownMarkerError = false;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final stream = _firestore.collection('property').snapshots();
    _markerSubscription = stream
        .asyncMap((snapshot) => _buildMarkersFromDocs(snapshot.docs))
        .listen(
      (loadedMarkers) {
        if (!mounted) return;
        setState(() {
          _markers
            ..clear()
            ..addAll(loadedMarkers);
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (!_hasShownMarkerError) {
          _hasShownMarkerError = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحميل العقارات: $error')),
          );
        }
      },
    );
  }

  Future<Set<Marker>> _buildMarkersFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final Set<Marker> loadedMarkers = {};
    final Set<String> activePropertyIds = {};

    for (final doc in docs) {
      try {
        final property = Property.fromFirestore(doc);
        activePropertyIds.add(property.uid);
        final geoPoint = property.location_coordinate;

        if (geoPoint.latitude == 0 && geoPoint.longitude == 0) {
          continue;
        }

        final LatLng position =
            LatLng(geoPoint.latitude.toDouble(), geoPoint.longitude.toDouble());
        final String signature = _markerSignature(property);

        BitmapDescriptor icon;
        final BitmapDescriptor? cachedIcon = _markerIconCache[property.uid];
        final String? cachedSignature = _markerIconSignatures[property.uid];

        if (cachedIcon != null && cachedSignature == signature) {
          icon = cachedIcon;
        } else {
          try {
            icon = await _createMarkerIcon(property);
          } catch (error, stackTrace) {
            debugPrint('⚠️ Failed to build marker for ${property.uid}: $error');
            debugPrintStack(stackTrace: stackTrace);
            icon = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            );
          }
          _markerIconCache[property.uid] = icon;
          _markerIconSignatures[property.uid] = signature;
        }

        loadedMarkers.add(
          Marker(
            markerId: MarkerId('property_${property.uid}'),
            position: position,
            icon: icon,
            onTap: () => _openPropertyDetails(property),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('⚠️ Failed to process property ${doc.id}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _markerIconCache.removeWhere(
      (key, _) => !activePropertyIds.contains(key),
    );
    _markerIconSignatures.removeWhere(
      (key, _) => !activePropertyIds.contains(key),
    );

    return loadedMarkers;
  }

  String _markerSignature(Property property) {
    return [
      property.title,
      property.price,
      property.image,
      property.rooms,
      property.bathrooms,
      property.area,
      property.type,
      property.purchaseType.name,
      property.location_name,
      property.propertyAge,
    ].join('|');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  TextEditingController search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
    _listenToPropertyUpdates();

    _yesNoAnswers = List.generate(
      _aiQuestions.length,
      (index) => {'question': _aiQuestions[index], 'answer': 'لا'},
    );
  }

  Future<void> _checkUserPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        return;
      }

      final userId = user.uid;

      final docSnapshot =
          await _firestore.collection('preferred_areas').doc(userId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        await _loadUserPreferences(docSnapshot.data()!);
      } 
    } catch (e) {
      print('Error checking preferences: $e');
    }
  }

  Future<void> _loadUserPreferences(Map<String, dynamic> data) async {
    try {
      final districts = data['districts'] as List<dynamic>?;

      if (districts != null && districts.isNotEmpty) {
        setState(() {
          _districts.clear();

          for (int i = 0; i < districts.length; i++) {
            final district = districts[i];
            final coordinate = district['coordinate'] as Map<String, dynamic>;
            final colorStr = district['color'] as String? ?? 'green';

            final lat = _toDouble(coordinate['latitude']);
            final lng = _toDouble(coordinate['longitude']);

            Color circleColor;
            switch (colorStr.toLowerCase()) {
              case 'green':
                circleColor = Colors.green;
                break;
              case 'yellow':
                circleColor = Colors.amber;
                break;
              case 'red':
                circleColor = Colors.red;
                break;
              default:
                circleColor = Colors.green;
            }

            _districts.add(
              Circle(
                circleId: CircleId('saved_$i'),
                center: LatLng(lat, lng),
                radius: 1500,
                fillColor: circleColor.withOpacity(0.3),
                strokeColor: circleColor,
                strokeWidth: 2,
              ),
            );
          }
        });

      }
    } catch (e) {
      print(' Error loading preferences: $e');
    }
  }

  @override
  void dispose() {
    _markerSubscription?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: _initialPosition,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: _markers,
              circles: _districts,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'استعراض العقارات',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اكتشف العقارات المتاحة في مدينة الرياض',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    GooglePlaceAutoCompleteTextField(
                      textEditingController: search,
                      googleAPIKey: dotenv.get("GOOGLE_MAP_API"),
                      inputDecoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        hintText: "ابحث عن منطقة...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      countries: ["sa"],
                      debounceTime: 800,
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) async {
                        if (prediction.lat != null && prediction.lng != null) {
                          final LatLng target = LatLng(
                            double.parse(prediction.lat!),
                            double.parse(prediction.lng!),
                          );
                          await _mapController.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: target,
                                zoom: 16,
                              ),
                            ),
                          );
                        }
                      },
                      itemClick: (Prediction prediction) {
                        search.text = prediction.description!;
                        search.selection = TextSelection.fromPosition(
                            TextPosition(
                                offset: prediction.description!.length));
                      },
                      itemBuilder: (context, index, Prediction prediction) {
                        return Container(
                          color: Colors.white,
                          padding: EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Icon(Icons.location_on),
                              SizedBox(width: 7),
                              Expanded(
                                  child:
                                      Text("${prediction.description ?? ""}"))
                            ],
                          ),
                        );
                      },
                      isCrossBtnShown: true,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10.h,
              left: 0,
              right: 0,
              child: Center(
                  child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ElevatedButton(
                  onPressed: _showAiAssistant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تعيين الذكاء الاصطناعي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8.sp),
                      const Icon(Icons.smart_toy, color: Colors.white),
                    ],
                  ),
                ),
              )),
            ),
            if (_isLoading)
              const Center(
                child: Card(
                  color: Colors.white,
                  elevation: 3,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('جاري تحميل الخريطة...'),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 60.h,
              right: 16.w,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'zoomInButton', // Unique heroTag
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.animateCamera(CameraUpdate.zoomIn());
                    },
                    child: Icon(Icons.add, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'zoomOutButton', // Unique heroTag
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.animateCamera(CameraUpdate.zoomOut());
                    },
                    child: Icon(Icons.remove, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPropertyDetails(Property property) {
    if (!mounted) return;
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
                  onTap: () {}, 
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

  }

  // Helper method to safely convert dynamic values to double
  double _toDouble(dynamic v) {
    if (v == null) throw Exception('Missing coordinate');
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String)
      return double.tryParse(v.replaceAll(',', '')) ??
          double.parse(v);
    throw Exception('Unsupported coordinate type: ${v.runtimeType}');
  }

  // AI Assistant variables and methods (keeping your original code)
  final PageController _aiPageController = PageController();
  int _currentAiPage = 0;
  bool _isProcessing = false;
  String _selectedPropertyType = '';
  double _budget = 1000000;
  Set<Circle> _selectedAreas = {};
  int _selectedAreaCount = 0;
  Map<String, dynamic>? _apiResponse;

  final List<String> _aiQuestions = [
    'هل تفضل القرب من محطة ميترو ؟',
    'هل تفضل القرب من المولات والمناطق الترفيهية ؟',
    'هل تفضل المناطق الهادئة؟',
    'هل تفضل الاحياء الحديثة ؟',
    'هل تفضل القرب من الطرق الرئيسية',
  ];
  List<Map<String, String>> _yesNoAnswers = [];

  void _showAiAssistant() {
    // Reset values
    _currentAiPage = 0;
    _selectedPropertyType = '';
    _budget = 1000000;
    _yesNoAnswers = List.generate(
      _aiQuestions.length,
      (index) =>
          {'question': _aiQuestions[index], 'answer': 'لا'}, // Default to "لا"
    );
    _selectedAreas.clear();
    _selectedAreaCount = 0;
    _isProcessing = false;
    _apiResponse = null;

    _aiQuestions.shuffle();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _buildAiAssistantModal(),
    );
  }

  Widget _buildAiAssistantModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      _currentAiPage == 4 ? 'النتائج' : 'المساعد الذكي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2575FC),
                      ),
                    ),
                    _currentAiPage < 3
                        ? Text(
                            '${_currentAiPage + 1}/3',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ),

              // Progress bar (only show for first 3 pages)
              if (_currentAiPage < 3)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: LinearProgressIndicator(
                    value: (_currentAiPage + 1) / 3,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF2575FC),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

              Expanded(
                child: PageView(
                  controller: _aiPageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setModalState(() => _currentAiPage = page);
                  },
                  children: [
                    _buildGeneralInfoPage(setModalState),
                    _buildYesNoQuestionsPage(setModalState),
                    _buildAreaSelectionPage(setModalState),
                    _buildLoadingPage(),
                    _buildResultsPage(setModalState),
                  ],
                ),
              ),

              // Navigation buttons (hide on loading and results pages)
              if (_currentAiPage < 3 && !_isProcessing)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if (_currentAiPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _aiPageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF2575FC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('السابق'),
                          ),
                        ),
                      if (_currentAiPage > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_purchaseType.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('خطأ'),
                                  content:
                                      const Text('الرجاء اختيار طريقة الشراء'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('حسناً'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            if (_selectedPropertyType.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('خطأ'),
                                  content:
                                      const Text('الرجاء اختيار نوع العقار'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('حسناً'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            if (_currentAiPage < 2) {
                              _aiPageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else if (_selectedAreaCount == 0) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('خطأ'),
                                  content: const Text(
                                      'الرجاء تحديد منطقة واحدة على الأقل'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('حسناً'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Navigate to loading page
                              _aiPageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );

                              setModalState(() {
                                _isProcessing = true;
                              });

                              try {

                                final apiResponse = await _sendApiRequest();

                                setModalState(() {
                                  _apiResponse = apiResponse;
                                  _isProcessing = false;
                                });

                                if (apiResponse['points'] != null) {
                                  setState(() {
                                    _districts.clear();
                                    List<Map<String, dynamic>> districtsData = [];
                                    
                                    final points = apiResponse['points'] as List<dynamic>;
                                    for (var point in points) {
                                      final coordinates = point['coordinates'] as List<dynamic>;
                                      if (coordinates.isNotEmpty) {
                                        final firstCoord = coordinates[0];
                                        final lat = _toDouble(firstCoord['latitude']);
                                        final lng = _toDouble(firstCoord['longitude']);
                                        final color = point['color'] as String? ?? 'green';
                                        final name = point['name'] as String? ?? '';

                                        Color circleColor;
                                        switch (color.toLowerCase()) {
                                          case 'green':
                                            circleColor = Colors.green;
                                            break;
                                          case 'yellow':
                                            circleColor = Colors.amber;
                                            break;
                                          case 'red':
                                            circleColor = Colors.red;
                                            break;
                                          default:
                                            circleColor = Colors.green;
                                        }

                                        _districts.add(
                                          Circle(
                                            circleId: CircleId('ai_${_districts.length}'),
                                            center: LatLng(lat, lng),
                                            radius: 1500,
                                            fillColor: circleColor.withOpacity(0.3),
                                            strokeColor: circleColor,
                                            strokeWidth: 2,
                                          ),
                                        );

                                        // Prepare data for Firebase
                                        districtsData.add({
                                          'color': color.toLowerCase() == 'yellow' ? 'orange' : color.toLowerCase(),
                                          'coordinate': {
                                            'latitude': lat.toString(),
                                            'longitude': lng.toString(),
                                          },
                                          'name': name,
                                        });
                                      }
                                    }

                                    // Store to Firebase
                                    _storeDistrictsToFirebase(districtsData);
                                  });
                                }

                                _aiPageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } catch (e) {
                                setModalState(() {
                                  _isProcessing = false;
                                });

                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('خطأ'),
                                    content: Text('فشل في تحليل البيانات: $e'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('حسناً'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2575FC),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(_currentAiPage == 2 ? 'تعيين' : 'التالي'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsPage(StateSetter setModalState) {
    // Extract neighborhoods from API response
    final List<Map<String, dynamic>> neighborhoods = [];

    if (_apiResponse != null && _apiResponse!['points'] != null) {
      final points = _apiResponse!['points'] as List<dynamic>;
      for (var point in points) {
        final name =
            (point['Name'] as String? ?? 'Unknown').split('،')[0].trim();
        final color = point['color'] as String? ?? 'green';

        // Check if neighborhood already exists
        if (!neighborhoods.any((n) => n['name'] == name)) {
          neighborhoods.add({
            'name': name,
            'color': color,
          });
        }
      }
    }

    // Fallback to default if no API response
    if (neighborhoods.isEmpty) {
      neighborhoods.addAll([
        {'name': 'حي النرجس', 'color': 'green'},
        {'name': 'حي الياسمين', 'color': 'yellow'},
        {'name': 'حي الصحافة', 'color': 'red'},
      ]);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2575FC),
                  const Color(0xFF1A73E8),
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2575FC),
                    size: 35,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تم تحليل البيانات والاستنتاج!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تم تخصيص الخريطة بناءً على تفضيلاتك',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Neighborhoods section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2575FC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'الأحياء المقترحة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: neighborhoods.map((neighborhood) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorFromString(neighborhood['color']!)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _getColorFromString(neighborhood['color']!),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color:
                                  _getColorFromString(neighborhood['color']!),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            neighborhood['name']!,
                            style: TextStyle(
                              color: _getColorFromString(neighborhood['color']!)
                                  .withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Color Legend section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2575FC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'دليل الألوان',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildColorLegendItem(
                        color: Colors.green,
                        label: 'يُنصح به جداً',
                        icon: Icons.star,
                        description: 'يتوافق بشكل ممتاز مع تفضيلاتك',
                      ),
                      const SizedBox(height: 12),
                      _buildColorLegendItem(
                        color: Colors.amber,
                        label: 'خيار متوسط',
                        icon: Icons.thumb_up_outlined,
                        description: 'يتوافق بشكل جيد مع بعض تفضيلاتك',
                      ),
                      const SizedBox(height: 12),
                      _buildColorLegendItem(
                        color: Colors.red,
                        label: 'خيار عادي',
                        icon: Icons.info_outline,
                        description: 'يتوافق بشكل محدود مع تفضيلاتك',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Map section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2575FC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'الخريطة المخصصة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(24.7136, 46.6753),
                            zoom: 11,
                          ),
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationButtonEnabled: false,
                          mapType: MapType.normal,
                          circles: _buildColoredCircles(),
                        ),
                    
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('عرض على الخريطة الرئيسية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2575FC),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorLegendItem({
    required Color color,
    required String label,
    required IconData icon,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Set<Circle> _buildColoredCircles() {
    // Use API response circles if available, otherwise use default
    if (_apiResponse != null && _apiResponse!['points'] != null) {
      final Set<Circle> circles = {};
      final points = _apiResponse!['points'] as List<dynamic>;

      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        final coordinates = point['coordinates'] as List<dynamic>;
        if (coordinates.isNotEmpty) {
          final firstCoord = coordinates[0];
          final lat = _toDouble(firstCoord['latitude']);
          final lng = _toDouble(firstCoord['longitude']);
          final color = point['color'] as String? ?? 'green';

          Color circleColor;
          switch (color.toLowerCase()) {
            case 'green':
              circleColor = Colors.green;
              break;
            case 'yellow':
              circleColor = Colors.amber;
              break;
            case 'red':
              circleColor = Colors.red;
              break;
            default:
              circleColor = Colors.green;
          }

          circles.add(
            Circle(
              circleId: CircleId('result_$i'),
              center: LatLng(lat, lng),
              radius: 1500,
              fillColor: circleColor.withOpacity(0.3),
              strokeColor: circleColor,
              strokeWidth: 2,
            ),
          );
        }
      }

      return circles;
    }

    // Default circles if no API response
    return {
      Circle(
        circleId: const CircleId('green_1'),
        center: const LatLng(24.7136, 46.6753),
        radius: 1500,
        fillColor: Colors.green.withOpacity(0.3),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('green_2'),
        center: const LatLng(24.7200, 46.6800),
        radius: 1500,
        fillColor: Colors.green.withOpacity(0.3),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ),
    };
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoadingPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loader
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating circle
                TweenAnimationBuilder(
                  duration: const Duration(seconds: 5),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * 6.28,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2575FC).withOpacity(0.2),
                            width: 4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Inner rotating circle
                TweenAnimationBuilder(
                  duration: const Duration(seconds: 5),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: -value * 6.28,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2575FC).withOpacity(0.4),
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Central icon
                const Icon(
                  Icons.location_searching,
                  size: 40,
                  color: Color(0xFF2575FC),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'جاري تحليل البيانات...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2575FC),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'يرجى عدم إغلاق الصفحة لمدة ٥ ثواني',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  String _purchaseType = ''; 
  double _minBudget = 500000;
  double _maxBudget = 5000000;

  void _updateBudgetRange() {
    if (_purchaseType == 'buy') {
      switch (_selectedPropertyType) {
        case 'villa':
          _minBudget = 1000000;
          _maxBudget = 10000000;
          break;
        case 'house':
          _minBudget = 800000;
          _maxBudget = 8000000;
          break;
        case 'apartment':
          _minBudget = 400000;
          _maxBudget = 5000000;
          break;
        default:
          _minBudget = 500000;
          _maxBudget = 5000000;
      }
    } else if (_purchaseType == 'rent') {
      switch (_selectedPropertyType) {
        case 'villa':
          _minBudget = 40000;
          _maxBudget = 200000;
          break;
        case 'house':
          _minBudget = 30000;
          _maxBudget = 150000;
          break;
        case 'apartment':
          _minBudget = 15000;
          _maxBudget = 100000;
          break;
        default:
          _minBudget = 15000;
          _maxBudget = 100000;
      }
    }

    if (_budget < _minBudget) _budget = _minBudget;
    if (_budget > _maxBudget) _budget = _maxBudget;
  }

  Widget _buildGeneralInfoPage(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and description
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2575FC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                size: 40,
                color: Color(0xFF2575FC),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'دعنا نساعدك في العثور على العقار المناسب',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'أخبرنا عن احتياجاتك وسنستخدم الذكاء الاصطناعي لاقتراح أفضل العقارات لك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Purchase type selection
          Text(
            'طريقة الشراء',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _purchaseTypeOption(
                  'شراء',
                  'buy',
                  Icons.attach_money_outlined,
                  _purchaseType == 'buy',
                  () {
                    setModalState(() {
                      _purchaseType = 'buy';
                      _updateBudgetRange();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _purchaseTypeOption(
                  'ايجار',
                  'rent',
                  Icons.key_outlined,
                  _purchaseType == 'rent',
                  () {
                    setModalState(() {
                      _purchaseType = 'rent';
                      _updateBudgetRange();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Property type selection
          Text(
            'نوع العقار',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _propertyTypeOption(
                  'فيلا',
                  'villa',
                  Icons.villa_outlined,
                  _selectedPropertyType == 'villa',
                  () {
                    setModalState(() {
                      _selectedPropertyType = 'villa';
                      if (_purchaseType.isNotEmpty) {
                        _updateBudgetRange();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _propertyTypeOption(
                  'بيت',
                  'house',
                  Icons.house,
                  _selectedPropertyType == 'house',
                  () {
                    setModalState(() {
                      _selectedPropertyType = 'house';
                      if (_purchaseType.isNotEmpty) {
                        _updateBudgetRange();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _propertyTypeOption(
                  'شقة',
                  'apartment',
                  Icons.apartment_outlined,
                  _selectedPropertyType == 'apartment',
                  () {
                    setModalState(() {
                      _selectedPropertyType = 'apartment';
                      if (_purchaseType.isNotEmpty) {
                        _updateBudgetRange();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Budget selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _purchaseType == 'rent' ? 'الإيجار السنوي' : 'الميزانية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2575FC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2575FC).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _formatCurrency(_budget),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2575FC),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCurrency(_minBudget),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _formatCurrency(_maxBudget),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ensure slider value is always within [min, max] range
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2575FC),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFF2575FC),
              overlayColor: const Color(0xFF2575FC).withOpacity(0.2),
              valueIndicatorColor: const Color(0xFF2575FC),
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              min: _minBudget,
              max: _maxBudget,
              divisions: 50,
              value: _budget.clamp(_minBudget, _maxBudget),
              label: _formatCurrency(
                _budget.clamp(_minBudget, _maxBudget),
              ),
              onChanged: (value) {
                setModalState(() => _budget = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoQuestionsPage(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and description
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2575FC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 40,
                color: Color(0xFF2575FC),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'أخبرنا عن تفضيلاتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'كلما قدمت لنا المزيد من المعلومات، كلما كانت نتائجنا أكثر دقة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Yes/No questions
          for (int i = 0; i < _aiQuestions.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _buildYesNoQuestion(
              _aiQuestions[i],
              _yesNoAnswers[i]['answer'] == 'نعم',
              (value) => setModalState(() {
                _yesNoAnswers[i]['answer'] = value ? 'نعم' : 'لا';
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaSelectionPage(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and description
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2575FC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 40,
                    color: Color(0xFF2575FC),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'حدد المناطق المفضلة لديك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  child: Text(
                    'انقر على المناطق التي تفضلها على الخريطة لتحديدها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Map for area selection
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(24.7136, 46.6753),
                  zoom: 10,
                ),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
                circles: _selectedAreas,
                onTap: (LatLng position) {
                  setModalState(() {
                    final String circleId =
                        'selected_area_${DateTime.now().millisecondsSinceEpoch}';

                    _selectedAreas.add(
                      Circle(
                        circleId: CircleId(circleId),
                        center: position,
                        radius: 1500, // 1.5km radius
                        fillColor: const Color(0xFF2575FC).withOpacity(0.2),
                        strokeColor: const Color(0xFF2575FC),
                        strokeWidth: 2,
                      ),
                    );

                    _selectedAreaCount = _selectedAreas.length;
                  });
                },
              ),

              // Instructions overlay
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'انقر لتحديد المناطق | عدد المناطق: $_selectedAreaCount',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _purchaseTypeOption(
    String label,
    String value,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2575FC).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2575FC) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2575FC).withOpacity(0.15)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? const Color(0xFF2575FC) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2575FC) : Colors.grey[800],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _propertyTypeOption(
    String label,
    String value,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2575FC).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2575FC) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? const Color(0xFF2575FC) : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2575FC) : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYesNoQuestion(
      String question, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              _buildYesNoButton(
                label: 'نعم',
                isSelected: value == true,
                onTap: () => onChanged(true),
              ),
              const SizedBox(width: 8),
              _buildYesNoButton(
                label: 'لا',
                isSelected: value == false,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2575FC) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2575FC) : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    // Format as Saudi Riyal with commas
    String formatted = value.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formatted ر.س';
  }


  Future<Map<String, dynamic>> _sendApiRequest() async {
    try {
      String defaultUrl = 'http://localhost:3000';
      

      final String baseUrl = dotenv.env['BACKEND_URL'] ?? defaultUrl;
      final String apiUrl = '$baseUrl/api/ai/ask';


      String propertyType = _selectedPropertyType.isNotEmpty
          ? _selectedPropertyType
          : 'apartment';

      final requestData = {
        'type': propertyType,
        'amount': _budget.toInt(),
        'questions_answers': _yesNoAnswers,
        'points': _selectedAreas.map((circle) {
          return {
            'latitude': circle.center.latitude,
            'longitude': circle.center.longitude,
          };
        }).toList(),
      };

      final response = await _dio.post(
        apiUrl,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data;
    } catch (e) {
      print(' Error calling API: $e');

      String errorMessage = 'فشل في تحليل البيانات';
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        errorMessage =
            'لا يمكن الاتصال بالخادم. تأكد من تشغيل الخادم على المنفذ 3000';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى';
      } else {
        errorMessage = 'فشل في تحليل البيانات: ${e.toString()}';
      }

      throw Exception(errorMessage);
    }
  }

Future<void> _storeDistrictsToFirebase(List<Map<String, dynamic>> districtsData) async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user logged in');
      return;
    }

    await FirebaseFirestore.instance
        .collection('preferred_areas')
        .doc(userId)
        .set({
      'districts': districtsData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); 

    print('Districts stored/updated successfully');
  } catch (e) {
    print('Error storing districts: $e');
  }
}
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated loader
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer rotating circle
                  TweenAnimationBuilder(
                    duration: const Duration(seconds: 5),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 6.28, // Full rotation
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2575FC).withOpacity(0.2),
                              width: 4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Inner rotating circle
                  TweenAnimationBuilder(
                    duration: const Duration(seconds: 5),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: -value *
                            6.28, // Full rotation in opposite direction
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2575FC).withOpacity(0.4),
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Central icon
                  const Icon(
                    Icons.location_searching,
                    size: 40,
                    color: Color(0xFF2575FC),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'جاري تحليل البيانات...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2575FC),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'يرجى عدم إغلاق الصفحة لمدة ٥ ثواني',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


