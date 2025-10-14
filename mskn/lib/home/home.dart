import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mskn/home/favorite.dart';
// Note: You must ensure Firebase is initialized in your main() function
// E.g., await Firebase.initializeApp();

// -----------------------------------------------------------------------------
// 0. PROPERTY MODEL (UPDATED)
// -----------------------------------------------------------------------------

/// 🏡 Property Model
class Property {
  final String title;
  final String location;
  final String price;
  final String image;
  final String type; // NEW: Added property type

  Property({
    required this.title,
    required this.location,
    required this.price,
    required this.image,
    required this.type,
  });

  // Helper to get price as a double for filtering
  double get priceValue => double.tryParse(price.replaceAll(',', '')) ?? 0.0;

  /// 🔥 Factory constructor to create a Property from a Firestore DocumentSnapshot
  factory Property.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Extract the first image URL from the 'images' array field
    final List<dynamic> imagesList =
        data['images'] is List ? data['images'] : [];
    final String imageUrl = imagesList.isNotEmpty && imagesList[0] is String
        ? imagesList[0]
        : 'https://via.placeholder.com/300x400.png?text=No+Image'; // Fallback image

    return Property(
      // Mapping the fields based on your Firestore structure
      title: data['title'] ?? 'عنوان غير متوفر',
      location: data['location_name'] ?? 'موقع غير متوفر',
      price: data['price'] ?? '0', // Price as a string
      type: data['type'] ?? 'غير مصنف', // The Arabic property type
      image: imageUrl,
    );
  }
}

// -----------------------------------------------------------------------------
// 1. FIREBASE SERVICE (NEW)
// -----------------------------------------------------------------------------

/// ☁️ Service to handle fetching properties from Firestore
class FirestoreService {
  // Assuming your collection name is 'poroperty' based on the screenshot
  static const String collectionName = 'poroperty';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a stream of all properties
  Stream<List<Property>> getProperties() {
    return _db.collection(collectionName).snapshots().map((snapshot) {
      // Map each document snapshot to a Property object
      return snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
    });
  }
}

// -----------------------------------------------------------------------------
// 2. UTILITY FUNCTIONS & DUMMY DATA (UPDATED)
// -----------------------------------------------------------------------------

/// 📝 دالة مساعدة لتوحيد وتسهيل مطابقة الأحرف العربية
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

// Removed dummyProperties list. Data will come from Firestore.

// ... (Previous imports and Property model remain unchanged)

// -----------------------------------------------------------------------------
// 3. MAIN PAGE & WIDGETS (UPDATED: _showPriceFilterDialog)
// -----------------------------------------------------------------------------

/// 🏠 Main Home Page
class HomeMainPage extends StatefulWidget {
  const HomeMainPage({super.key});

  @override
  State<HomeMainPage> createState() => _HomeMainPageState();
}

class _HomeMainPageState extends State<HomeMainPage> {
  String selectedTag = 'عرض الكل';
  String searchQuery = '';

  // Max price is 50,000,000 for calculation
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

  /// 💰 Handle Price Filter - UPDATED to handle cancellation
  Future<void> _showPriceFilterDialog() async {
    // The dialog now returns RangeValues on success, or null on cancel.
    final result = await showDialog<RangeValues>(
      context: context,
      builder: (context) => PriceFilterDialog(initialRange: priceRange),
    );

    if (result != null) {
      // User pressed 'تطبيق الفلتر' (Apply Filter)
      setState(() {
        priceRange = result;
        // Check if filter is active (not the default range)
        isFilterActive = result.start > 0 || result.end < 50000000;
      });
    } else {
      // User pressed 'إلغاء' (Cancel) OR dismissed the dialog
      // Reset the filter state to default
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
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 10.0), // Reduced horizontal padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Right side: 'مسكن'
                const Text(
                  'مسكن',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const Spacer(flex: 2), // Gives more space to the center
                // Center: Location
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.black),
                const SizedBox(width: 4),
                const Text('الرياض',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(flex: 1),
                // Left side: Icons (Saved and Notification)
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FavoritePage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {},
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
                  // 'عقارات جديدة' (New Properties) title aligned to the right
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

// -----------------------------------------------------------------------------
// 4. PROPERTY GRID (UNCHANGED)
// -----------------------------------------------------------------------------

/// 🧱 Property Grid View (Updated to use StreamBuilder)
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

  /// Helper function to apply all filters to the list fetched from Firestore
  List<Property> _applyFilters(List<Property> properties) {
    final normalizedQuery = _normalizeArabic(searchQuery);

    // Map the Arabic Tag (from the UI buttons) to the corresponding Arabic Type (from Firestore document 'type')
    final Map<String, List<String>> tagToTypeMap = {
      'شقق': ['شقة', 'شقق'],
      'فلل': ['فلة', 'فيلا', 'فلل'],
      'بيوت': ['بيت', 'بيوت'],
      'أراضي': ['أرض', 'اراضي'],
    };

    return properties.where((property) {
      final normalizedTitle = _normalizeArabic(property.title);
      final normalizedLocation = _normalizeArabic(property.location);
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
          // Show loading indicator while fetching data
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
          // Show empty state
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
          // Ensure it scrolls naturally with the SingleChildScrollView
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
          // 🛑 UPDATED: Pop the dialog and return null to signal cancellation
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

// ... (Rest of the widgets: FilterButton, SearchBar, PropertyTagsRow, PropertyCard, BottomNavigationBarPlaceholder, etc., remain unchanged)
// The rest of the code is unchanged from your last submission.
/// 💰 Filter Button (Unchanged)
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

// -----------------------------------------------------------------------------
// 6. PROPERTY CARD (UPDATED FOR NETWORK IMAGE)
// -----------------------------------------------------------------------------

/// 🖼️ Property Card UI (With Animation)
class PropertyCard extends StatefulWidget {
  final Property property;
  const PropertyCard({super.key, required this.property});

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

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
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isPressed ? 0.2 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.all(8.0),
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
                      widget.property.location,
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
