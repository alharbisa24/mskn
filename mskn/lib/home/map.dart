import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';


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
  final Set<Polygon> _polygons = {};
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
  final double borderRadius = 20; // حواف كبيرة

  // رسم الخلفية (مربع بحواف مستديرة)
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

  // رسم السعر داخل المربع
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
            
          },
        ),
      );
    }

    _polygons.add(
      Polygon(
        polygonId: const PolygonId('area1'),
        points: const [
          LatLng(24.832939056890655, 46.73280028691015),
          LatLng(24.830928123510418, 46.72940875905422),
          LatLng(24.82776801935842, 46.72782604605479),
          LatLng(24.82768593765659, 46.73677967959444),
        ],
        strokeColor: Colors.red,
        strokeWidth: 2,
        fillColor: Colors.red.withOpacity(0.3),
      ),
    );

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
              polygons: _polygons,
              markers: _markers,
              circles: {
                Circle(
                  circleId: const CircleId('premium_area'),
                  center: const LatLng(24.7316, 46.6753),
                  radius: 1500,
                  fillColor: Colors.green.withOpacity(0.2),
                  strokeColor: Colors.green,
                  strokeWidth: 1,
                ),
              },
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
}