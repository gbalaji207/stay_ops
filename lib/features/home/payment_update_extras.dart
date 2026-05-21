import '../../shared/models/booking_group.dart';
import '../../shared/models/payment_destination.dart';

class PaymentUpdateExtras {
  const PaymentUpdateExtras({
    required this.group,
    required this.activeDestinations,
  });

  final BookingGroup group;
  final List<PaymentDestination> activeDestinations;
}
