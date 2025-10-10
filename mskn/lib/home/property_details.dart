import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetails extends StatefulWidget {
  const PropertyDetails({super.key});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  int _currentImageIndex = 0;
final CarouselSliderController _carouselController = CarouselSliderController();

  bool isFavorite = false;
  
  final Map<String, dynamic> propertyData = {
    'title': 'فيلا فاخرة في حي النرجس',
    'price': 2500000,
    'location': {
      'address': 'حي النرجس، شمال الرياض، المملكة العربية السعودية',
      'coordinates': const LatLng(24.7869, 46.6669),
    },
    'type': 'فيلا',
    'purchaseType': 'بيع',
    'area': 350,
    'rooms': 5,
    'bathrooms': 4,
    'streetWidth': 16,
    'propertyAge': '١٠ سنين',
    'licenseNumber': 'LIC-2023-748591',
    'seller': {
      'name': 'أحمد محمد',
      'phone': '0555123456',
      'email': 'ahmed@example.com',
      'avatar': 'https://randomuser.me/api/portraits/men/32.jpg',
      'rating': 4.8,
      'type':'seller',
    },
    'description': 'فيلا فاخرة ومميزة في حي النرجس بتصميم عصري، تتميز بموقع استراتيجي قريب من الخدمات والمرافق العامة. تحتوي على صالة كبيرة ومجلس رجال ونساء ومطبخ مجهز بالكامل وغرف نوم واسعة مع حمامات خاصة. الفيلا مجهزة بأنظمة تكييف مركزية وأنظمة أمان متطورة.',
    'images': [
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      'https://images.unsplash.com/photo-1600566752355-35792bedcfea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1474&q=80',
    ],
    'features': ['حديقة خارجية', 'مسبح خاص', 'موقف سيارات', 'غرفة خادمة', 'مصعد', 'مطبخ مجهز'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
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
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.black87),
                    onPressed: () {
                      // Share property functionality
                    },
                  ),
                ),
              ),
            ],
          ),

          // 2. Main Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Carousel
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
                      items: propertyData['images'].map<Widget>((imageUrl) {
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
                          '${_currentImageIndex + 1}/${propertyData['images'].length}',
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

                // Property title and price
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
                            child: Text(
                              propertyData['title'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_formatNumber(propertyData['price'])} ريال',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A73E8),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A73E8).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  propertyData['purchaseType'],
                                  style: const TextStyle(
                                    color: Color(0xFF1A73E8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              propertyData['location']['address'],
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Key Features
                      _buildKeyFeatures(),

                      const SizedBox(height: 24),

                      // Map view
                      _buildMapView(),

                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'وصف العقار',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        propertyData['description'],
                        style: TextStyle(
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),

                      const SizedBox(height: 24),

                 
                      _buildLicenseDetails(),

                      const SizedBox(height: 24),

                      // Seller details
                      _buildSellerDetails(),

                      const SizedBox(height: 100), // Extra space for bottom navigation bar
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Contact action buttons
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1A73E8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('اتصال'),
                  onPressed: () async {
                    final Uri uri = Uri(
                      scheme: 'tel',
                      path: propertyData['seller']['phone'],
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('مراسلة'),
                  onPressed: () {
                    // Open chat with seller
                  },
                ),
              ),
            ],
          ),
        ),
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
          Expanded(child: _buildKeyFeatureItem(Icons.king_bed_outlined, '${propertyData['rooms']} غرف')),
          Expanded(child: _buildKeyFeatureItem(Icons.bathtub_outlined, '${propertyData['bathrooms']} حمامات')),
          Expanded(child: _buildKeyFeatureItem(Icons.square_foot_outlined, '${propertyData['area']} م²')),
        ],
          ),
          const SizedBox(height: 16),
          // Second row
          Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildKeyFeatureItem(Icons.straighten_outlined, '${propertyData['streetWidth']} م')),
          Expanded(child: _buildKeyFeatureItem(Icons.calendar_month, '${propertyData['propertyAge']}')),
          Expanded(child: _buildKeyFeatureItem(Icons.category, '${propertyData['type']}')),
        ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
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
              initialCameraPosition: CameraPosition(
                target: propertyData['location']['coordinates'],
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('property'),
                  position: propertyData['location']['coordinates'],
                  infoWindow: InfoWindow(title: propertyData['title']),
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
                      propertyData['licenseNumber'],
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
  // Get first two letters of seller's name for the avatar
  final String sellerInitials = propertyData['seller']['name']
      .split(' ')
      .take(2)
      .map((e) => e.isNotEmpty ? e[0] : '')
      .join('')
      .toUpperCase();
      
  // Check if the user is a seller
  final bool isSeller = propertyData['seller']['type'] == 'seller';
  
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
                    propertyData['seller']['name'],
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
        
        // Show license details and contact options only for sellers
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
                    const Text(
                      'RE-5423789',
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
                    const Text(
                      '15/08/2024',
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
          
          // Contact options
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
                    final phoneNumber = propertyData['seller']['phone'];
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
                    // Make a call to the seller's phone number
                    final phoneNumber = propertyData['seller']['phone'];
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
                    launchUrl(Uri.parse('https://twitter.com/user'));
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
                    launchUrl(Uri.parse('https://instagram.com/user'));
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
                    launchUrl(Uri.parse('https://snapchat.com/add/user'));
                  },
                ),
              ),
            
        ],)
      
      ],
    ),
  );
}
  String _formatNumber(int number) {
    final String numberStr = number.toString();
    final StringBuffer result = StringBuffer();
    
    for (int i = 0; i < numberStr.length; i++) {
      if (i > 0 && (numberStr.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(numberStr[i]);
    }
    
    return result.toString();
  }
}