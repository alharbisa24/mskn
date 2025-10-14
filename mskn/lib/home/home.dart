import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mskn/home/favorite.dart';
import 'package:mskn/home/models/property.dart';
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

  /// 🏷️ Handle Tag Selection
  void _handleTagSelection(String tag) {
    setState(() => selectedTag = tag);
  }

  /// 🔍 Handle Search Input
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
          // Custom App Bar / Header - START
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 16.0.h, vertical: 10.0.w), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'مسكن',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textDirection: TextDirection.rtl,
                ),

                const Spacer(flex: 1), 
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.black),
                const SizedBox(width: 4),
                const Text('الرياض',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(flex: 1),
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
          // Custom App Bar / Header - END
          const Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey), // Small separator line
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
                      // Search Bar
                      Expanded(
                        child: SearchBar(onSearchChanged: _handleSearch),
                      ),
                      const SizedBox(width: 8),
                      // فلترة (Filter) Button
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
                      'عقارات جديدة',
                      textAlign: TextAlign.right,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 🧱 Property Grid (Now fetches from Firestore)
                  PropertyGrid(
                    selectedTag: selectedTag,
                    searchQuery: searchQuery,
                    priceRange: priceRange,
                  ),
                ],
              ),
            ),
          ),
          // Placeholder for bottom navigation
          BottomNavigationBarPlaceholder(),
        ],
      ),
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

    final Map<String, List<String>> tagToTypeMap = {
      'شقق': ['شقة', 'شقق'],
      'فلل': ['فلة', 'فيلا', 'فلل'],
      'بيوت': ['بيت', 'بيوت'],
      'أراضي': ['أرض', 'اراضي'],
    };

    return properties.where((property) {
      final normalizedTitle = _normalizeArabic(property.title);
      final normalizedLocation = _normalizeArabic(property.location_name);
      final normalizedType = _normalizeArabic(property.type);

      // 1. Tag Filter
      bool matchesTag = selectedTag == 'عرض الكل';
      if (!matchesTag) {
        final List<String> targetTypes = tagToTypeMap[selectedTag] ?? [];

        // Check if the property's *type* field matches any of the target types (after normalization)
        matchesTag = targetTypes.any((targetType) =>
            normalizedType.contains(_normalizeArabic(targetType)));
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
          // Show error message
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

// -----------------------------------------------------------------------------
// 5. PRICE FILTER DIALOG (UPDATED: 'إلغاء' button action)
// -----------------------------------------------------------------------------

/// 💰 Price Filter Dialog
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

/// 🏷️ Property Type Filter Buttons (Unchanged)
class PropertyTagsRow extends StatefulWidget {
  final ValueChanged<String> onTagSelected;
  const PropertyTagsRow({super.key, required this.onTagSelected});

  @override
  State<PropertyTagsRow> createState() => _PropertyTagsRowState();
}

class _PropertyTagsRowState extends State<PropertyTagsRow> {
  final List<String> tags = const ['عرض الكل', 'فلل', 'شقق', 'أراضي', 'بيوت'];
  String selectedTag = 'عرض الكل';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // Scroll from right-to-left
      child: Row(
        children: tags.reversed.map((tag) {
          final bool isSelected = tag == selectedTag;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: ActionChip(
              label: Text(
                tag,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
              onPressed: () {
                setState(() => selectedTag = tag);
                widget.onTagSelected(tag);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }
}


class PropertyCard extends StatefulWidget {
  final Property property;
  const PropertyCard({super.key, required this.property});

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {

  /// ✅ Format price with commas (e.g. 1000000 → 1,000,000)
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
  backgroundColor: Colors.transparent, // ضروري لخلفية شفافة
  builder: (context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // يلتقط الضغط في أي مكان فارغ
      onTap: () => Navigator.of(context).pop(), // يغلق الـ bottom sheet
      child: Stack(
        children: [
          // المحتوى الشفاف بالخلف (النقر عليه يغلق)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)), // يعطي ظل خفيف
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
                  onTap: () {}, // يمنع الإغلاق عند النقر داخل المحتوى
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
      
        ),
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
              Expanded(
                child: Image.network(
                  widget.property.image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          size: 40, color: Colors.grey),
                    );
                  },
                ),
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
                    const SizedBox(height: 4),
                    Text(
                      widget.property.location_name,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    // 💰 Price formatted with commas
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

// -----------------------------------------------------------------------------
// 7. BOTTOM NAVIGATION BAR (UNCHANGED)
// -----------------------------------------------------------------------------

/// 📱 Bottom Navigation Bar Placeholder
class BottomNavigationBarPlaceholder extends StatelessWidget {
  const BottomNavigationBarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: This is a placeholder. You'd typically use a real BottomNavigationBar
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _NavBarItem(
      {required this.icon, required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
      ),
      padding: const EdgeInsets.all(8.0),
      child: const Icon(Icons.add, color: Colors.white, size: 24),
    );
  }
}
