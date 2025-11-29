import 'dart:async';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  // Text controllers
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _locationName = TextEditingController();
  final _area = TextEditingController();
  final _rooms = TextEditingController();
  final _propertyAge = TextEditingController();
  final _streetWidth = TextEditingController();
  final _bathrooms = TextEditingController();
  final _description = TextEditingController();

  // Dropdowns
  String _purchaseType = 'sell'; // sell | rent
  String _type = 'فيلا'; // فيلا | شقة | قصر | استديو | دوبلكس

  // Images
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedImages = [];

  // Location
  double? _lat;
  double? _lng;

  // Auth + Role
  String? _rank; // seller / buyer
  String? _licenseNumber; // from seller profile
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  @override
  void initState() {
    super.initState();
    _watchUserRank();
  }

  void _watchUserRank() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _profileSub = FirebaseFirestore.instance
        .collection('profile')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      setState(() {
        final data = doc.data();
        _rank = data?['rank'];
        _licenseNumber = (data?['license_number'] ?? '').toString();
      });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _title.dispose();
    _price.dispose();
    _locationName.dispose();
    _area.dispose();
    _rooms.dispose();
    _propertyAge.dispose();
    _streetWidth.dispose();
    _bathrooms.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() {
        _pickedImages
          ..clear()
          ..addAll(images.take(8)); 
      });
    }
  }

Future<List<Map<String, String>>> _uploadImages(String propertyId, String sellerId) async {
  final storage = FirebaseStorage.instance;
  final List<Map<String, String>> images = [];

  for (int i = 0; i < _pickedImages.length; i++) {
    final file = File(_pickedImages[i].path);

    final filename = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
    final path = 'properties/$propertyId/$filename';

    final ref = storage.ref().child(path);

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await task.ref.getDownloadURL();

    images.add({
      "url": url,
      "path": path, 
    });
  }

  return images;
}


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('يجب تسجيل الدخول لإضافة عقار');
      return;
    }
    if (_rank != 'seller') {
      _showError('هذه الميزة متاحة للبائعين فقط');
      return;
    }
    if (_pickedImages.isEmpty) {
      _showError('الرجاء اختيار صور للعقار');
      return;
    }
    setState(() => _submitting = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('property').doc();

      final imageUrls = await _uploadImages(docRef.id, user.uid);

      await docRef.set({
        'title': _title.text.trim(),
        'price': _price.text.trim(),
        'location_name': _locationName.text.trim(),
        'location_coordinate': (_lat != null && _lng != null)
            ? GeoPoint(_lat!, _lng!)
            : const GeoPoint(0, 0),
        'area': _area.text.trim(),
        'rooms': _rooms.text.trim(),
        'propertyAge': _propertyAge.text.trim(),
        'streetWidth': _streetWidth.text.trim(),
        'bathrooms': _bathrooms.text.trim(),
        'description': _description.text.trim(),
        'purchaseType': _purchaseType, 
        'type': _type, 
        'seller_id': user.uid,
        'licence_number': _licenseNumber ?? '',
        'images': imageUrls,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.bottomSlide,
        title: 'نجاح',
        desc: 'تم إضافة العقار بنجاح',
        btnOkOnPress: () {},
      ).show();
      _resetForm();
    } catch (e) {
      _showError('حدث خطأ أثناء إضافة العقار: $e');
      print(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _title.clear();
    _price.clear();
    _locationName.clear();
    _area.clear();
    _rooms.clear();
    _propertyAge.clear();
    _streetWidth.clear();
    _bathrooms.clear();
    _description.clear();
    _pickedImages.clear();
    _lat = null;
    _lng = null;
    setState(() {});
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = _rank == 'seller';
    final googleApiKey = dotenv.get("GOOGLE_MAP_API");

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار')),
      body: SafeArea(
        child: (_rank == null)
            ? const Center(child: CircularProgressIndicator())
            : (!isSeller)
                ? const Center(child: Text('هذه الميزة للبائعين فقط'))
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Images picker
                          Text('صور العقار',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._pickedImages.map((x) => Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(x.path),
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: InkWell(
                                          onTap: () {
                                            setState(
                                                () => _pickedImages.remove(x));
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.all(2),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                              GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Icon(Icons.add_a_photo),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title
                          TextFormField(
                            controller: _title,
                            decoration:
                                const InputDecoration(labelText: 'العنوان'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'الرجاء إدخال العنوان'
                                : null,
                          ),

                          // Price
                          TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'السعر (ريال)'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'الرجاء إدخال السعر'
                                : null,
                          ),

                          // Location
                          const SizedBox(height: 8),
                          if (googleApiKey.isNotEmpty) ...[
                            Text('الموقع',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            GooglePlaceAutoCompleteTextField(
                              textEditingController: _locationName,
                              googleAPIKey: googleApiKey,
                              isLatLngRequired: true,
                              debounceTime: 600,
                              countries: const ['sa'],
                              getPlaceDetailWithLatLng: (Prediction p) {
                                if (p.lat != null && p.lng != null) {
                                  setState(() {
                                    _lat = double.tryParse(p.lat!);
                                    _lng = double.tryParse(p.lng!);
                                  });
                                }
                              },
                              itemClick: (Prediction p) {
                                _locationName.text = p.description ?? '';
                                _locationName.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _locationName.text.length),
                                );
                              },
                              itemBuilder: (context, index, Prediction p) {
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(p.description ?? ''),
                                );
                              },
                              inputDecoration: const InputDecoration(
                                labelText: 'ابحث عن الموقع',
                                prefixIcon: Icon(Icons.search),
                              ),
                              isCrossBtnShown: true,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final res = await Navigator.of(context)
                                          .push<MapPickerResult>(
                                        MaterialPageRoute(
                                          builder: (_) => MapPickerScreen(
                                            initial:
                                                (_lat != null && _lng != null)
                                                    ? LatLng(_lat!, _lng!)
                                                    : null,
                                          ),
                                        ),
                                      );
                                      if (res != null) {
                                        setState(() {
                                          _lat = res.lat;
                                          _lng = res.lng;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.place),
                                    label: const Text('تحديد من الخريطة'),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _locationName,
                              decoration: const InputDecoration(
                                  labelText: 'اسم الموقع (بدون خرائط)'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'الرجاء إدخال الموقع'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final res = await Navigator.of(context)
                                          .push<MapPickerResult>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MapPickerScreen(),
                                        ),
                                      );
                                      if (res != null) {
                                        setState(() {
                                          _lat = res.lat;
                                          _lng = res.lng;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.place),
                                    label: const Text('تحديد من الخريطة'),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (_lat != null && _lng != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'الإحداثيات المختارة',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Chip(
                                          label: Text(
                                              '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => setState(() {
                                            _lat = null;
                                            _lng = null;
                                          }),
                                          icon: const Icon(Icons.clear),
                                          label: const Text('مسح'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _area,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'المساحة (م²)'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'المساحة مطلوبة'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _rooms,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'عدد الغرف'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'عدد الغرف مطلوب'
                                          : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _propertyAge,
                                  decoration: const InputDecoration(
                                      labelText: 'عمر العقار (بالسنوات)'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'عمر العقار مطلوب'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _streetWidth,
                                  decoration: const InputDecoration(
                                      labelText: 'عرض الشارع (متر)'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'عرض الشارع مطلوب'
                                          : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _bathrooms,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'عدد دورات المياه (اختياري)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _purchaseType,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'sell', child: Text('بيع')),
                                    DropdownMenuItem(
                                        value: 'rent', child: Text('إيجار')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _purchaseType = v ?? 'sell'),
                                  decoration: const InputDecoration(
                                      labelText: 'نوع العملية'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            items: const [
                              DropdownMenuItem(
                                  value: 'فيلا', child: Text('فيلا')),
                              DropdownMenuItem(
                                  value: 'شقة', child: Text('شقة')),
                              DropdownMenuItem(
                                  value: 'ارض', child: Text('ارض')),
                              DropdownMenuItem(
                                  value: 'بيت', child: Text('بيت')),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'فيلا'),
                            decoration:
                                const InputDecoration(labelText: 'نوع العقار'),
                          ),

                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _description,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'الوصف (اختياري)'),
                          ),

                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(
                                  _submitting ? 'يتم الحفظ...' : 'حفظ العقار'),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class MapPickerResult {
  final double lat;
  final double lng;
  const MapPickerResult({required this.lat, required this.lng});
}

class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(24.7136, 46.6753); // Riyadh
  late CameraPosition _initialCamera;
  LatLng? _selected;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initialCamera =
        CameraPosition(target: widget.initial ?? _defaultCenter, zoom: 12);
  }

  void _onTap(LatLng pos) {
    setState(() {
      _selected = pos;
      _markers
        ..clear()
        ..add(Marker(markerId: const MarkerId('picked'), position: pos));
    });
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(
        MapPickerResult(lat: _selected!.latitude, lng: _selected!.longitude));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختر موقع العقار')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: (c) {},
            onTap: _onTap,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _selected == null ? null : _confirm,
              icon: const Icon(Icons.check),
              label: Text(_selected == null
                  ? 'انقر على الخريطة لاختيار الموقع'
                  : 'تأكيد الموقع (${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)})'),
            ),
          ),
        ],
      ),
    );
  }
}