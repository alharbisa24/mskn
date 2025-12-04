import 'package:cloud_firestore/cloud_firestore.dart';

enum PropertyPurchaseType {
  sell,
  rent,
  other,
}

enum PropertyType {
  villa,
  apartment,
  land,
}

extension PropertyPurchaseTypeExtension on PropertyPurchaseType {
  String get arabic {
    switch (this) {
      case PropertyPurchaseType.sell:
        return 'بيع';
      case PropertyPurchaseType.rent:
        return 'ايجار';
      case PropertyPurchaseType.other:
        return 'آخر';
    }
  }
}

class Property {
  final String uid;
  final String title;
  final String price;
  final String image;
  final String area;
  final String bathrooms;
  final String description;
  final String licence_number;
  final GeoPoint location_coordinate;
  final String location_name;
  final String propertyAge;
  final PropertyPurchaseType purchaseType;
  final String rooms;
  final String streetWidth;
  final String type;
  final List images;
  final String? seller_id;

  Property({
    required this.uid,
    required this.title,
    required this.location_name,
    required this.price,
    required this.type,
    required this.image,
    this.area = '',
    this.bathrooms = '',
    this.description = '',
    this.licence_number = '',
    this.location_coordinate = const GeoPoint(0, 0),
    this.propertyAge = '',
    this.purchaseType = PropertyPurchaseType.other,
    this.rooms = '',
    this.streetWidth = '',
    this.images = const [],
    this.seller_id,
  });

  double get priceValue => double.tryParse(price.replaceAll(',', '')) ?? 0.0;

  factory Property.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Normalize images to a List<String> of URLs (backward compatible)
    final List<dynamic> rawImages =
        data['images'] is List ? data['images'] : [];
    final List<String> imagesList = [];
    for (final item in rawImages) {
      if (item is String && item.trim().isNotEmpty) {
        imagesList.add(item.trim());
      } else if (item is Map &&
          item['url'] is String &&
          (item['url'] as String).trim().isNotEmpty) {
        imagesList.add((item['url'] as String).trim());
      }
    }
    final String imageUrl = imagesList.isNotEmpty
        ? imagesList.first
        : 'https://via.placeholder.com/300x400.png?text=No+Image';

    // تحويل purchaseType من string إلى enum
    PropertyPurchaseType typeEnum;
    switch ((data['purchaseType'] ?? '').toString().toLowerCase()) {
      case 'sell':
      case 'بيع':
        typeEnum = PropertyPurchaseType.sell;
        break;
      case 'rent':
      case 'ايجار':
        typeEnum = PropertyPurchaseType.rent;
        break;
      default:
        typeEnum = PropertyPurchaseType.other;
    }

    return Property(
      uid: doc.id,
      title: data['title'] ?? 'No Title',
      location_name: data['location_name'] ?? 'No Location',
      price: data['price'] ?? '0',
      type: data['type'] ?? 'No Type',
      area: data['area'] ?? '',
      bathrooms: data['bathrooms'] ?? '',
      description: data['description'] ?? '',
      licence_number: data['licence_number'] ?? '',
      location_coordinate: data['location_coordinate'] ?? const GeoPoint(0, 0),
      propertyAge: data['propertyAge'] ?? '',
      purchaseType: typeEnum,
      rooms: data['rooms'] ?? '',
      streetWidth: data['streetWidth'] ?? '',
      images: imagesList,
      image: imageUrl,
      seller_id: data['seller_id'],
    );
  }
}
