import '../../../shared/models/booking_group.dart';

class BookingWizardExtras {
  const BookingWizardExtras({
    this.prefilledRoomId,
    this.prefilledDate,
    this.existingGroup,
  });
  final String? prefilledRoomId;
  final DateTime? prefilledDate;
  final BookingGroup? existingGroup;
}
