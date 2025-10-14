import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mskn/home/models/property.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetails extends StatefulWidget {
  Property property;
  PropertyDetails({super.key, required this.property});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  int _currentImageIndex = 0;
final CarouselSliderController _carouselController = CarouselSliderController();

  bool isFavorite = false;
  

 Map<String,dynamic>? seller_profile;
  bool isLoading = true;


late LatLng position;

@override
void initState() {
  super.initState();

  position = LatLng(
    widget.property.location_coordinate.latitude,
    widget.property.location_coordinate.longitude,
  );

  _loadSeller();
}

 
  Future<void> _loadSeller() async {
        final doc = await FirebaseFirestore.instance
        .collection('profile')
        .doc(widget.property.seller_id)
        .get();

    setState(() {
      seller_profile = doc.data();
      isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.white,
      body:
      SafeArea(
        child:
       CustomScrollView(
        slivers: [
       SliverAppBar(
  pinned: true, // يجعل الـ AppBar ثابتًا في الأعلى أثناء التمرير
  floating: true, // يسمح له بالظهور عند التمرير للأعلى
  snap: true, // يتيح له "القفز" عند التمرير للأعلى إذا استخدم floating
  expandedHeight: 0, // لا حاجة لتوسيع
  backgroundColor: Colors.transparent, // خلفية شفافة
  elevation: 0, // بدون ظل
  leading: Padding(
    padding: const EdgeInsets.all(8.0),
    child: CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.6), // نصف شفاف
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
          onPressed: () {
            setState(() {
              isFavorite = !isFavorite;
            });
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

    final RenderBox box = context.findRenderObject() as RenderBox;

    Share.share(
      shareText,
      sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
    );
      },
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
                    // Image counter indicator
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    // Image navigation buttons
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.4),
                          child: const Icon(Icons.chevron_right, color: Colors.white),
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
                          child: const Icon(Icons.chevron_left, color: Colors.white),
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
    // عنوان العقار
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

    // السعر ونوع البيع
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // السعر
        Text(
          '${widget.property.price} ريال',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A73E8),
          ),
        ),

        const SizedBox(height: 6),

        // نوع البيع (شراء / إيجار)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8).withOpacity(0.15),
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

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 18),
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

                      // Key Features
                      _buildKeyFeatures(),

                       SizedBox(height: 24.h),

                      // Map view
                      _buildMapView(),

                     SizedBox(height: 24.h),

                      // Description
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

                      // Seller details
                      _buildSellerDetails(),

                       SizedBox(height:100.h), 
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
        padding:  EdgeInsets.symmetric(horizontal: 25.h, vertical: 12.w),
        child: 
         isLoading 
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
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedWhatsapp, size: 18),
            label: const Text('واتساب'),
            onPressed: () {
              final phoneNumber = seller_profile?['phone'] ?? '';
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
              final phoneNumber = seller_profile?['phone'] ?? '';
              launchUrl(Uri.parse('tel:$phoneNumber'));
            },
          ),
        ),
      ],
    )
      
      ),
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
          // First row
          Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildKeyFeatureItem(Icons.king_bed_outlined, '${widget.property.rooms} غرف')),
          Expanded(child: _buildKeyFeatureItem(Icons.bathtub_outlined, '${widget.property.bathrooms} حمامات')),
          Expanded(child: _buildKeyFeatureItem(Icons.square_foot_outlined, '${widget.property.area} م²')),
        ],
          ),
          const SizedBox(height: 16),
          // Second row
          Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildKeyFeatureItem(Icons.straighten_outlined, '${widget.property.streetWidth} م')),
          Expanded(child: _buildKeyFeatureItem(Icons.calendar_month, '${widget.property.propertyAge}')),
          Expanded(child: _buildKeyFeatureItem(Icons.category, '${widget.property.type}')),
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
                  position:position,
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
  if (isLoading || seller_profile == null) {
    // عرض shimmer loader أثناء التحميل
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
            Container(height: 12, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 4)),
            Container(height: 12, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 4)),
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

  // إذا البيانات جاهزة، نرجع نفس Widget الأصلي
  final String sellerInitials = (seller_profile?['name'] ?? 'مستخدم')
      .split(' ')
      .take(2)
      .map((e) => e.isNotEmpty ? e[0] : '')
      .join('')
      .toUpperCase();
      
  final bool isSeller = seller_profile?['rank'] == 'seller';

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
            // Google-style avatar with initials
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
                    seller_profile?['name'] ?? 'مستخدم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            color: isSeller ? const Color(0xFF1A73E8) : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        if (isSeller) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // License details
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
                      seller_profile?['license_number'] ,
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
                      seller_profile?['licence_expired'] ,
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
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedWhatsapp, size: 18),
                  label: const Text('واتساب'),
                  onPressed: () {
                    final phoneNumber = seller_profile?['phone'] ?? '';
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
                    final phoneNumber = seller_profile?['phone'] ?? '';
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
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedTwitter, color: Colors.white, size: 18),
                  onPressed: () {
                    launchUrl(Uri.parse('https://twitter.com/${seller_profile?['x']}'));
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFFE1306C),
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedInstagram, color: Colors.white, size: 18),
                  onPressed: () {
                    launchUrl(Uri.parse('https://instagram.com/${seller_profile?['instagram']}'));
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFFFFFC00),
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedSnapchat, color: Colors.black, size: 18),
                  onPressed: () {
                    launchUrl(Uri.parse('https://snapchat.com/add/${seller_profile?['snapchat']}'));
                  },
                ),
              ),
            
        ],)
    
      ],
    )
  
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