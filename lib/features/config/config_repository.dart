import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import '../../shared/models/room.dart';

class ConfigRepository {
  final _client = Supabase.instance.client;

  Future<List<Room>> fetchRooms() async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .order('sort_order');
    return (response as List).map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BookingType>> fetchBookingTypes() async {
    final response = await _client
        .from('booking_types')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .order('sort_order');
    return (response as List).map((e) => BookingType.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BookingSource>> fetchBookingSources() async {
    final response = await _client
        .from('booking_sources')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .eq('is_active', true)
        .order('sort_order');
    return (response as List).map((e) => BookingSource.fromJson(e as Map<String, dynamic>)).toList();
  }
}
