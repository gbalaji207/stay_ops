import '../../../shared/models/booking_group.dart';
import 'sf_booking_prefill.dart';

class BookingWizardExtras {
  const BookingWizardExtras({
    this.prefilledRoomId,
    this.prefilledDate,
    this.existingGroup,
    this.sfPrefill,
  });
  final String? prefilledRoomId;
  final DateTime? prefilledDate;
  final BookingGroup? existingGroup;
  final SfBookingPrefill? sfPrefill;
}
