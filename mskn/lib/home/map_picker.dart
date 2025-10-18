import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
