import '../shared/models/property_info.dart';

enum UserRole { none, staff, owner }

class AppConstants {
  static String get propertyId => AppSession._activePropertyId;
  static String get sfHotelId => AppSession._activeSfHotelId;
}

class AppSession {
  static String _activePropertyId = '';
  static String _activeSfHotelId = '';

  static void setActiveProperty(PropertyInfo property) {
    _activePropertyId = property.id;
    _activeSfHotelId = property.sfHotelId ?? '';
  }
}
