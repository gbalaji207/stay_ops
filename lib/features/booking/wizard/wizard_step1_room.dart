import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/room.dart';

class WizardStep1Room extends StatelessWidget {
  const WizardStep1Room({
    super.key,
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomSelected,
  });

  final List<Room> rooms;
  final String? selectedRoomId;
  final ValueChanged<String> onRoomSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (rooms.isEmpty) {
      return Center(
        child: Text(
          'No rooms configured.\nAdd rooms in Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: rooms.length,
      separatorBuilder: (_, i) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final room = rooms[i];
        final selected = room.id == selectedRoomId;
        return GestureDetector(
          onTap: () => onRoomSelected(room.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? colors.accentSubtle : colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 20,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? colors.accent : colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
