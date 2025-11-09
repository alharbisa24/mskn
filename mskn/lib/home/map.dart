import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:io';

import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:dio/dio.dart';

final Dio _dio = Dio(); // Initialize Dio for API requests

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
  final Random _random = Random();

  final List<String> _propertyTypes = [
    'فيلا',
    'شقة',
    'قصر',
    'استديو',
    'دوبلكس',
  ];

  LatLng _getRandomLocation() {
    const double minLat = 24.5700;
    const double maxLat = 24.8500;
    const double minLng = 46.6000;
    const double maxLng = 46.8000;
    
    final double lat = minLat + _random.nextDouble() * (maxLat - minLat);
    final double lng = minLng + _random.nextDouble() * (maxLng - minLng);
    
    return LatLng(lat, lng);
  }
Future<BitmapDescriptor> _createMarkerIcon(String price, Color color) async {
  final PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final double width = 120;
  final double height = 60;
  final double borderRadius = 20; 

  final Paint paint = Paint()..color = color;
  final RRect rRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, width, height),
    Radius.circular(borderRadius),
  );
  canvas.drawRRect(rRect, paint);

  // رسم ظل خفيف أسفل المربع
  final Paint shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.2)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  canvas.drawRRect(rRect.shift(const Offset(2, 3)), shadowPaint);

  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: price,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.bold,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
  );
  textPainter.layout(minWidth: width, maxWidth: width);
  textPainter.paint(canvas, Offset(0, (height - textPainter.height)/2));

  final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}


  Future<void> _loadMarkers() async {
    setState(() {
      _isLoading = true;
    });

    final List<Color> markerColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
    ];

    for (int i = 0; i < 15; i++) {
      final LatLng position = _getRandomLocation();
      final String price = '1000';
      final String propertyType = _propertyTypes[_random.nextInt(_propertyTypes.length)];
      final Color markerColor = markerColors[_random.nextInt(markerColors.length)];
      
      final BitmapDescriptor markerIcon = await _createMarkerIcon(price, markerColor);
      
      _markers.add(
        Marker(
          markerId: MarkerId('property_$i'),
          position: position,
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: '$propertyType للبيع',
            snippet: '$price ريال - ${_random.nextInt(5) + 1} غرف',
          ),
onTap: () {
  _showPropertyBottomSheet(
    imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
    title: 'فيلا فاخرة شمال الرياض',
    price: price,
    type: propertyType,
    saleType: _random.nextBool() ? 'شراء' : 'إيجار',
    area: 320 + _random.nextInt(180),
    rooms: _random.nextInt(5) + 2,
    bathrooms: _random.nextInt(3) + 1,
    streetWidth: 10 + _random.nextInt(15),
    description:
        'فيلا مميزة تقع في موقع استراتيجي قريب من الخدمات والمدارس، تصميم عصري وتشطيبات فاخرة.',
  );
},
        ),
      );
    }

  

    setState(() {
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }


TextEditingController search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMarkers();

    // Initialize _yesNoAnswers here
    _yesNoAnswers = List.generate(
      _aiQuestions.length,
      (index) => {'question': _aiQuestions[index], 'answer': 'لا'}, // Default to "لا"
    );
  }

  @override
  void dispose() {
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),

                        countries: ["sa"],
                        debounceTime: 800,
                        isLatLngRequired:true,
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
      TextPosition(offset: prediction.description!.length));
},
        itemBuilder: (context, index, Prediction prediction) {
          return Container(
            color: Colors.white,
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.location_on),
                SizedBox(
                  width: 7,
                ),
                Expanded(child: Text("${prediction.description??""}"))
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
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
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
)
              ),
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

            // 🎛️ أزرار التحكم أسفل الخريطة
            Positioned(
              bottom: 60.h,
              right: 16.w,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.animateCamera(CameraUpdate.zoomIn());
                    },
                    child: Icon(Icons.add, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
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
  void _showPropertyBottomSheet({
  required String imageUrl,
  required String title,
  required String price,
  required String type,
  required String saleType,
  required int area,
  required int rooms,
  required int bathrooms,
  required int streetWidth,
  required String description,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المعاينة
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // المحتوى
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان والسعر
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2575FC), Color(0xFF2575FC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$price ر.س',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // النوع ونوع البيع
                  Row(
                    children: [
                      Icon(Icons.home_work_outlined, color: Colors.blueAccent.shade700, size: 22),
                      const SizedBox(width: 6),
                      Text(type, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 18),
                      Icon(Icons.swap_horiz_outlined, color: Colors.deepPurpleAccent, size: 22),
                      const SizedBox(width: 6),
                      Text(saleType, style: const TextStyle(fontSize: 15)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // تفاصيل الأرقام
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _infoChip(Icons.square_foot, '$area م²', 'المساحة'),
                      _infoChip(Icons.meeting_room, '$rooms', 'الغرف'),
                      _infoChip(Icons.bathtub_outlined, '$bathrooms', 'الحمامات'),
                      _infoChip(Icons.signpost_outlined, '$streetWidth م', 'عرض الشارع'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // الوصف
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // زر عرض التفاصيل
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2575FC),
                        padding: EdgeInsets.symmetric(vertical: 12.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                        'عرض التفاصيل',
                        style: TextStyle(fontSize: 16.sp, color: Colors.white),
                      ),
                      SizedBox(width: 2.sp),
                      Icon(Icons.arrow_circle_left),
                        ],
                      )
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

Widget _infoChip(IconData icon, String value, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
             const SizedBox(width: 5),

        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
                const SizedBox(width: 5),

           Text(
          '$value ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
// Add this to your _MapPageState class

// AI Assistant state variables
final PageController _aiPageController = PageController();
int _currentAiPage = 0;

bool _isProcessing = false;

// Selected values
String _selectedPropertyType = '';
double _budget = 1000000;

Set<Circle> _selectedAreas = {};
int _selectedAreaCount = 0;

// Store API response
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
    (index) => {'question': _aiQuestions[index], 'answer': 'لا'}, // Default to "لا"
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                content: const Text('الرجاء اختيار طريقة الشراء'),
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
                                content: const Text('الرجاء اختيار نوع العقار'),
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
                                content: const Text('الرجاء تحديد منطقة واحدة على الأقل'),
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
                              // Call the API
                              final apiResponse = await _sendApiRequest();
                              
                              // Store the API response
                              setModalState(() {
                                _apiResponse = apiResponse;
                                _isProcessing = false;
                              });
                              
                              // Update map circles with API response
                              if (apiResponse['points'] != null) {
                                setState(() {
                                  _districts.clear();
                                  final points = apiResponse['points'] as List<dynamic>;
                                  for (var point in points) {
                                    final coordinates = point['coordinates'] as List<dynamic>;
                                    if (coordinates.isNotEmpty) {
                                      final firstCoord = coordinates[0];
                                      final lat = firstCoord['latitude'] as double;
                                      final lng = firstCoord['longitude'] as double;
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
                                    }
                                  }
                                });
                              }
                              
                              // Navigate to results page
                              _aiPageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } catch (e) {
                              setModalState(() {
                                _isProcessing = false;
                              });
                              
                              // Show error dialog
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
      final name = (point['Name'] as String? ?? 'Unknown').split('،')[0].trim();
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
                const Color(0xFF6A11CB),
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
                            color: _getColorFromString(neighborhood['color']!),
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
                      // Overlay gradient for better visibility
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: const Color(0xFF2575FC),
                                  ),
                             
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Button to view on full map
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close modal
                    // The colored circles will remain on the main map
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
        final lat = firstCoord['latitude'] as double;
        final lng = firstCoord['longitude'] as double;
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

Widget _buildPropertyDetailSmall(IconData icon, String text) {
  return Row(
    children: [
      Icon(
        icon,
        size: 15,
        color: Colors.grey[600],
      ),
      const SizedBox(width: 3),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[700],
        ),
      ),
    ],
  );
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

String _formatPrice(int price) {
  return price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
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
String _purchaseType = ''; // 'buy' or 'rent'
double _minBudget = 500000;
double _maxBudget = 5000000;

// Add this method to update budget range based on property type and purchase type
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
  
  // Adjust current budget if it's out of new range
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            value: _budget,
            label: _formatCurrency(_budget),
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
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
                  final String circleId = 'selected_area_${DateTime.now().millisecondsSinceEpoch}';
                  
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

Widget _buildProcessingView() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF2575FC),
                ),
                backgroundColor: Colors.grey[200],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'جاري تحليل البيانات...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'نقوم الآن بتحليل تفضيلاتك لإيجاد أفضل الخيارات المناسبة لك',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
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
        color: isSelected ? const Color(0xFF2575FC).withOpacity(0.1) : Colors.grey[50],
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
        color: isSelected ? const Color(0xFF2575FC).withOpacity(0.1) : Colors.grey[50],
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


Widget _buildYesNoQuestion(String question, bool value, ValueChanged<bool> onChanged) {
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

/*
Future<Map<String, dynamic>> _sendApiRequest() async {
  try {
    final response = await _dio.post(
      'https://example.com/api/analyze', // Replace with your API endpoint
      data: {
        'type': _selectedPropertyType,
        'amount': _budget,
        'questions_answers': _yesNoAnswers,
        'points': _selectedAreas.map((circle) {
          return {
            'latitude': circle.center.latitude,
            'longitude': circle.center.longitude,
          };
        }).toList(),
      },
    );
    return response.data; // Return the API response
  } catch (e) {
    throw Exception('Failed to analyze data: $e');
  }
}*/
Future<Map<String, dynamic>> _sendApiRequest() async {
  try {
    // Get backend URL from environment or use platform-specific default
    String defaultUrl;
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      defaultUrl = 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      defaultUrl = 'http://localhost:3000';
    } else {
      // Desktop or other platforms
      defaultUrl = 'http://localhost:3000';
    }
    
    final String baseUrl = dotenv.env['BACKEND_URL'] ?? defaultUrl;
    final String apiUrl = '$baseUrl/api/ai/ask';
    
    print('🌐 Connecting to backend: $apiUrl');

    // Use the selected property type (already in English: 'villa', 'house', 'apartment')
    String propertyType = _selectedPropertyType.isNotEmpty 
        ? _selectedPropertyType 
        : 'apartment'; // default

    // Prepare request data
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

    // Send API request
    final response = await _dio.post(
      apiUrl,
      data: requestData,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // Return the API response
    return response.data;
  } catch (e) {
    print('❌ Error calling API: $e');
    
    // Provide more helpful error messages
    String errorMessage = 'فشل في تحليل البيانات';
    if (e.toString().contains('Connection refused') || e.toString().contains('SocketException')) {
      errorMessage = 'لا يمكن الاتصال بالخادم. تأكد من تشغيل الخادم على المنفذ 3000';
      if (Platform.isAndroid) {
        errorMessage += '\n\nللأجهزة الافتراضية: تأكد من استخدام http://10.0.2.2:3000';
      }
    } else if (e.toString().contains('Timeout')) {
      errorMessage = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى';
    } else {
      errorMessage = 'فشل في تحليل البيانات: ${e.toString()}';
    }
    
    throw Exception(errorMessage);
  }
}
void _showLoadingScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LoadingScreen(),
    ),
  );
}

  // This function is no longer used - the map now uses _districts directly
  // which gets updated from the API response
  Set<Circle> _buildDistrictsCircles() {
    // Return empty set - circles are now managed via _districts from API response
    return _districts;
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
                        angle: -value * 6.28, // Full rotation in opposite direction
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
// Add this method to show the results page
void _showResultsPage(BuildContext context, Map<String, dynamic> result) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ResultsPage(result: result),
    ),
  );
}

// Create a new ResultsPage widget
class ResultsPage extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultsPage({Key? key, required this.result}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    // Extract neighborhoods from points
    final points = result['points'] as List<dynamic>;
    final neighborhoods = <Map<String, dynamic>>[];
    
    for (var point in points) {
      final name = (point['Name'] as String).split('،')[0];
      final color = point['color'] as String;
      
      // Check if neighborhood already exists
      if (!neighborhoods.any((n) => n['name'] == name)) {
        neighborhoods.add({
          'name': name,
          'color': color,
        });
      }
    }

    // Hardcoded properties list
    final properties = [
      {
        'title': 'فيلا فاخرة مع مسبح خاص',
        'price': 2500000,
        'location': 'حي النرجس، شمال الرياض',
        'bedrooms': 5,
        'bathrooms': 4,
        'area': 450,
        'imageUrl': 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=400',
      },
      {
        'title': 'شقة مميزة بإطلالة رائعة',
        'price': 1200000,
        'location': 'حي الياسمين، شمال الرياض',
        'bedrooms': 3,
        'bathrooms': 2,
        'area': 180,
        'imageUrl': 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400',
      },
      {
        'title': 'فيلا حديثة بتصميم عصري',
        'price': 3200000,
        'location': 'حي الصحافة، شمال الرياض',
        'bedrooms': 6,
        'bathrooms': 5,
        'area': 520,
        'imageUrl': 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
      },
      {
        'title': 'شقة عائلية واسعة',
        'price': 950000,
        'location': 'حي الملقا، شمال الرياض',
        'bedrooms': 4,
        'bathrooms': 3,
        'area': 200,
        'imageUrl': 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'نتائج التحليل',
          style: TextStyle(
            color: Color(0xFF2575FC),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2575FC)),
      ),
      body: SingleChildScrollView(
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
                    const Color(0xFF6A11CB),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2575FC),
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تم تحليل البيانات والاستنتاج!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'وجدنا أفضل العقارات المناسبة لك',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2575FC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'الأحياء المقترحة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: neighborhoods.map((neighborhood) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorFromString(neighborhood['color'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getColorFromString(neighborhood['color']),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getColorFromString(neighborhood['color']),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              neighborhood['name'],
                              style: TextStyle(
                                color: _getColorFromString(neighborhood['color'])
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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

            const SizedBox(height: 32),

            // Properties section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2575FC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'العقارات المتوفرة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: properties.length,
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Property image
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                property['imageUrl'] as String,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    property['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Location
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        property['location'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Property details
                                  Row(
                                    children: [
                                      _buildPropertyDetail(
                                        Icons.bed_outlined,
                                        '${property['bedrooms']} غرف',
                                      ),
                                      const SizedBox(width: 16),
                                      _buildPropertyDetail(
                                        Icons.bathroom_outlined,
                                        '${property['bathrooms']} حمام',
                                      ),
                                      const SizedBox(width: 16),
                                      _buildPropertyDetail(
                                        Icons.square_foot_outlined,
                                        '${property['area']} م²',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Price and button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'السعر',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '${_formatPrice(property['price'] as int)} ر.س',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2575FC),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          // Navigate to property details
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2575FC),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('عرض التفاصيل'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
