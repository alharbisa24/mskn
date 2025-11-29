import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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

class PropertyDetails extends StatefulWidget {
  Property property;
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

    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {

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

      if (!mounted) return;

   AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: 'تم الحذف',
        desc: 'تم حذف العقار بنجاح.',
        btnOkText: 'حسناً',
        btnOkOnPress: () {
          if (navigator.canPop()) {
            navigator.pop();
          }
        },
        btnOkColor: Colors.green,
            ).show();
    } catch (error) {
      if (navigator.canPop()) {
        navigator.pop();
      }

      if (!mounted) return;

      AwesomeDialog(
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
        btnOkColor: Colors.red,
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
        title: 'تمت الاضفة',
        desc: 'تمت اضافة العقار لقائمة المفضلة بنجاح',
        btnOkText: 'حسناً',
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
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
                          return Builder(
                            builder: (BuildContext context) {
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
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
                            _carouselController.previousPage();
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
                            _carouselController.nextPage();
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
                                  style: const TextStyle(
                                    fontSize: 24,
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

                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.grey, size: 18),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                widget.property.location_name,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24.h),

                        _buildKeyFeatures(),

                        SizedBox(height: 24.h),

                        _buildMapView(),

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

                        _buildLicenseDetails(),

                        SizedBox(height: 24.h),

                        _buildSellerDetails(),

                        SizedBox(height: 100.h),
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
                'بيانات الترخيص',
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

              const SizedBox(height: 16),

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
                  backgroundColor: const Color(0xFF1DA1F2),
                  radius: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedTwitter,
                        color: Colors.white,
                        size: 18),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          'https://twitter.com/${sellerProfile?['x']}'));
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