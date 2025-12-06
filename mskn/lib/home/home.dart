import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart' as Lott;
import 'package:mskn/home/favorite.dart';
import 'package:mskn/home/models/property.dart';
import 'package:mskn/home/notifications_page.dart';
import 'package:mskn/home/property_details.dart';


class FirestoreService {
  static const String collectionName = 'property';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Property>> getProperties() {
    return _db.collection(collectionName).orderBy('created_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
    });
  }
}


String _normalizeArabic(String text) {
  String normalized = text.trim().toLowerCase();
  normalized =
      normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
  normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
  normalized = normalized.replaceAll(RegExp(r'[ى]'), 'ي');
  normalized = normalized.replaceAll('ة', 'ه');
  normalized = normalized.replaceAll('ؤ', 'و');
  return normalized;
}


class HomeMainPage extends StatefulWidget {
  const HomeMainPage({super.key});

  @override
  State<HomeMainPage> createState() => _HomeMainPageState();
}

class _HomeMainPageState extends State<HomeMainPage> {
  String selectedTag = 'عرض الكل';
  String searchQuery = '';

  RangeValues priceRange = const RangeValues(0, 50000000);
  bool isFilterActive = false;

  void _handleTagSelection(String tag) {
    setState(() => selectedTag = tag);
  }

  void _handleSearch(String query) {
    setState(() => searchQuery = query.trim());
  }

  Future<void> _showPriceFilterDialog() async {
    final result = await showDialog<RangeValues>(
      context: context,
      builder: (context) => PriceFilterDialog(initialRange: priceRange),
    );

    if (result != null) {
      setState(() {
        priceRange = result;
        isFilterActive = result.start > 0 || result.end < 50000000;
      });
    } else {

      setState(() {
        priceRange = const RangeValues(0, 50000000);
        isFilterActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 16.0.h, vertical: 10.0.w), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'images/logo.png',
                  width: 50.w,

                ),

                const Spacer(flex: 1), 
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.black),
                const SizedBox(width: 4),
                const Text('الرياض',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(flex: 1),
                _NotificationsIconButton(),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FavoritePage()),
                    );
                  },
                ),
      
              ],
            ),
          ),
          const Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey), 
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: SearchBar(onSearchChanged: _handleSearch),
                      ),
                      const SizedBox(width: 8),
                      FilterButton(
                        onPressed: _showPriceFilterDialog,
                        isActive: isFilterActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PropertyTagsRow(onTagSelected: _handleTagSelection),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'قائمة العقارات',
                      textAlign: TextAlign.right,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 10),
                  PropertyGrid(
                    selectedTag: selectedTag,
                    searchQuery: searchQuery,
                    priceRange: priceRange,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsIconButton extends StatefulWidget {
  const _NotificationsIconButton({super.key});

  @override
  State<_NotificationsIconButton> createState() =>
      _NotificationsIconButtonState();
}

class _NotificationsIconButtonState extends State<_NotificationsIconButton> {
  bool _seenThisSession = false;

  void _openNotifications(BuildContext context) {
    setState(() {
      _seenThisSession = true;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsStream =
        FirebaseFirestore.instance.collection('notifications').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return InkWell(
            onTap: (){
              _openNotifications(context);
            },
            child:  HugeIcon(icon: 
              HugeIcons.strokeRoundedNotification01, size: 25,),
            
          );
        }

        final count = docs.length;
        final showAlert = !_seenThisSession;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
             onTap: () => _openNotifications(context),

              child: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification01,
                size: 25,
                ),
            ),
      
            if (showAlert)
              Positioned(
                right: 2,
                top: -7,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


class PropertyGrid extends StatelessWidget {
  final String selectedTag;
  final String searchQuery;
  final RangeValues priceRange;
  final FirestoreService _firestoreService = FirestoreService();
  

  PropertyGrid({
    super.key,
    required this.selectedTag,
    required this.searchQuery,
    required this.priceRange,
  });

  List<Property> _applyFilters(List<Property> properties) {
    final normalizedQuery = _normalizeArabic(searchQuery);

    final Map<String, String> tagToTypeMap = {
      'شقق': 'شقة',
      'فلل': 'فيلا',
      'بيوت': 'بيت',
      'أراضي': 'ارض',
    };

    return properties.where((property) {
      final normalizedTitle = _normalizeArabic(property.title);
      final normalizedLocation = _normalizeArabic(property.location_name);
      final normalizedType = _normalizeArabic(property.type);

      // 1. Tag Filter
      bool matchesTag = selectedTag == 'عرض الكل';
      if (!matchesTag) {
        final String? targetType = tagToTypeMap[selectedTag];
        
        if (targetType != null) {
          matchesTag = normalizedType.contains(_normalizeArabic(targetType));
        }
      }

      // 2. Search Filter
      bool matchesSearch = normalizedQuery.isEmpty ||
          normalizedTitle.contains(normalizedQuery) ||
          normalizedLocation.contains(normalizedQuery);

      // 3. Price Filter
      bool matchesPrice = property.priceValue >= priceRange.start &&
          property.priceValue <= priceRange.end;

      return matchesTag && matchesSearch && matchesPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Property>>(
      stream: _firestoreService.getProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('خطأ في جلب البيانات: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'لا توجد عقارات حاليًا في قاعدة البيانات.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ));
        }

        // Apply filtering logic to the fetched properties
        final filteredProperties = _applyFilters(snapshot.data!);

        if (filteredProperties.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'لا توجد نتائج مطابقة لمرشحات البحث.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredProperties.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
            childAspectRatio: 0.70,
          ),
          itemBuilder: (context, index) {
            return PropertyCard(property: filteredProperties[index]);
          },
        );
      },
    );
  }
}

class PriceFilterDialog extends StatefulWidget {
  final RangeValues initialRange;
  const PriceFilterDialog({super.key, required this.initialRange});

  @override
  State<PriceFilterDialog> createState() => _PriceFilterDialogState();
}

class _PriceFilterDialogState extends State<PriceFilterDialog> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
  }

  String _formatPrice(double value) {
    final formatted = value.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formatted ريال';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('تحديد نطاق السعر', textAlign: TextAlign.right),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'من: ${_formatPrice(_currentRange.start)}',
            textAlign: TextAlign.right,
          ),
          Text(
            'إلى: ${_formatPrice(_currentRange.end)}',
            textAlign: TextAlign.right,
          ),
          RangeSlider(
            activeColor: Colors.blue,
            values: _currentRange,
            min: 0,
            max: 50000000,
            divisions: 50,
            labels: RangeLabels(
              _formatPrice(_currentRange.start),
              _formatPrice(_currentRange.end),
            ),
            onChanged: (RangeValues newValues) {
              setState(() {
                _currentRange = newValues;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          // Returns the selected range
          onPressed: () => Navigator.of(context).pop(_currentRange),
          child: const Text('تطبيق الفلتر'),
        ),
      ],
    );
  }
}


class FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isActive;
  const FilterButton(
      {super.key, required this.onPressed, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          Icons.tune,
          color: isActive ? Colors.white : Colors.black54,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// 🔍 Search Bar (Unchanged)
class SearchBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  const SearchBar({super.key, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: 'ابحث عن الحي...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade200,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
      onChanged: onSearchChanged,
    );
  }
}

class PropertyTagsRow extends StatefulWidget {
  final ValueChanged<String> onTagSelected;
  const PropertyTagsRow({super.key, required this.onTagSelected});

  @override
  State<PropertyTagsRow> createState() => _PropertyTagsRowState();
}

class _PropertyTagsRowState extends State<PropertyTagsRow> {
  final List<Map<String, dynamic>> tags = const [
    {'label': 'عرض الكل', 'icon': Icons.grid_view, 'color': Colors.blue},
    {'label': 'شقق', 'icon': Icons.apartment, 'color': Colors.orange},
    {'label': 'فلل', 'icon': Icons.villa, 'color': Colors.green},
    {'label': 'أراضي', 'icon': Icons.landscape, 'color': Colors.brown},
    {'label': 'بيوت', 'icon': Icons.home, 'color': Colors.purple},
  ];
  String selectedTag = 'عرض الكل';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: tags.map((tag) {
            final bool isSelected = tag['label'] == selectedTag;
            return Container(
              margin: EdgeInsets.only(right: 10.0.w),
              child: _buildFilterChip(
                label: tag['label'],
                icon: tag['icon'],
                color: tag['color'],
                isSelected: isSelected,
                onTap: () {
                  setState(() => selectedTag = tag['label']);
                  widget.onTagSelected(tag['label']);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }


class PropertyCard extends StatefulWidget {
  final Property property;
  const PropertyCard({super.key, required this.property});

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {

  String formatPrice(String price) {
    final numeric = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '0';
    final number = double.tryParse(numeric) ?? 0;
    final formatted = number.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
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
            child: Container(color: Colors.black.withOpacity(0.3)), 
          ),

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
                                    property: widget.property,

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


},

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
               boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
              side: BorderSide(
          color: Colors.grey.shade300, 
          width: 1, 
      ),
          ),
          elevation: 0,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Stack(
  children: [
    ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(20),
      ),
      child: Image.network(
        widget.property.images.isNotEmpty ? widget.property.images[0] : widget.property.image,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 140,
            color: Colors.grey[200],
            child: const Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          );
        },
      ),
    ),
    Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ),
    Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2575FC),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2575FC).withOpacity(0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          widget.property.type,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  ],
),

              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10.w,
                  horizontal: 10.h
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.property.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                     SizedBox(height: 4.h),
                       Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                       SizedBox(width: 4.h),
                        Expanded(
                          child: Text(
                            widget.property.location_name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                     SizedBox(height: 4.h),

                    Text(
                      '${formatPrice(widget.property.price)} ر.س',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

