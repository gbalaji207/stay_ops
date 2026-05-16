import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../shared/models/booking_source.dart';
import '../../shared/models/booking_type.dart';
import '../../shared/models/payment_destination.dart';
import '../../shared/models/room.dart';

class SettingsRepository {
  final _client = Supabase.instance.client;

  Future<String> fetchPropertyName() async {
    final response = await _client
        .from('properties')
        .select('name')
        .eq('id', AppConstants.propertyId)
        .single();
    return response['name'] as String;
  }

  Future<List<Room>> fetchAllRooms() async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .order('sort_order', ascending: true);
    return (response as List)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookingType>> fetchAllBookingTypes() async {
    final response = await _client
        .from('booking_types')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .order('sort_order', ascending: true);
    return (response as List)
        .map((e) => BookingType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookingSource>> fetchAllBookingSources() async {
    final response = await _client
        .from('booking_sources')
        .select('*,payment_destinations(id,name)')
        .eq('property_id', AppConstants.propertyId)
        .order('sort_order', ascending: true);
    return (response as List)
        .map((e) => BookingSource.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PaymentDestination>> fetchAllPaymentDestinations() async {
    final response = await _client
        .from('payment_destinations')
        .select()
        .eq('property_id', AppConstants.propertyId)
        .order('sort_order', ascending: true);
    return (response as List)
        .map((e) => PaymentDestination.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRoom(String name, int sortOrder) async {
    await _client.from('rooms').insert({
      'property_id': AppConstants.propertyId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateRoom(String id, String name) async {
    await _client.from('rooms').update({'name': name}).eq('id', id);
  }

  Future<void> setRoomActive(String id, {required bool isActive}) async {
    await _client.from('rooms').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> addBookingType(String name, int sortOrder) async {
    await _client.from('booking_types').insert({
      'property_id': AppConstants.propertyId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateBookingType(String id, String name) async {
    await _client.from('booking_types').update({'name': name}).eq('id', id);
  }

  Future<void> setBookingTypeActive(String id, {required bool isActive}) async {
    await _client
        .from('booking_types')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> addBookingSource(
    String name,
    String bookingTypeId,
    int sortOrder,
  ) async {
    await _client.from('booking_sources').insert({
      'property_id': AppConstants.propertyId,
      'name': name,
      'booking_type_id': bookingTypeId,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateBookingSource(String id, String name) async {
    await _client.from('booking_sources').update({'name': name}).eq('id', id);
  }

  Future<void> setBookingSourceActive(
    String id, {
    required bool isActive,
  }) async {
    await _client
        .from('booking_sources')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> updateBookingSourceDestination(
    String sourceId,
    String? destinationId,
  ) async {
    await _client
        .from('booking_sources')
        .update({'default_payment_destination_id': destinationId})
        .eq('id', sourceId);
  }

  Future<void> addPaymentDestination(String name, int sortOrder) async {
    await _client.from('payment_destinations').insert({
      'property_id': AppConstants.propertyId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updatePaymentDestination(String id, String name) async {
    await _client
        .from('payment_destinations')
        .update({'name': name})
        .eq('id', id);
  }

  Future<void> setPaymentDestinationActive(
    String id, {
    required bool isActive,
  }) async {
    await _client
        .from('payment_destinations')
        .update({'is_active': isActive})
        .eq('id', id);
  }
}
