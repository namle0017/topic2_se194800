import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../booking_controller.dart';
import '../components/booking_controls.dart';

class SearchPanel extends StatefulWidget {
  const SearchPanel({
    super.key,
    required this.booking,
    required this.onUseCurrentLocation,
  });
  final BookingController booking;
  final VoidCallback onUseCurrentLocation;
  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController text = TextEditingController(
    text: widget.booking.query,
  );
  Widget field(bool pickup) {
    final b = widget.booking;
    final active = pickup == b.editingPickup;
    final label = pickup
        ? b.pickupLabel
        : b.destination?.name ?? 'Bạn muốn đi đâu?';
    return Row(
      children: [
        StopDot(destination: !pickup),
        const SizedBox(width: 14),
        Expanded(
          child: active
              ? TextField(
                  controller: text,
                  autofocus: true,
                  key: const ValueKey('place-query'),
                  onChanged: b.updateQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: pickup ? 'Tìm điểm đón' : 'Tìm điểm đến',
                    suffixIcon: text.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: () {
                              text.clear();
                              b.updateQuery('');
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                )
              : Material(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => b.openSearch(pickupField: pickup),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: muted),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    // The entire form scrolls when the keyboard leaves little vertical space.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Lên kế hoạch chuyến đi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          field(true),
          const SizedBox(height: 8),
          field(false),
          if (b.editingPickup)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: b.locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 22),
              title: const Text(
                'Chọn vị trí hiện tại của bạn',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                b.locationFailure?.message ?? b.locationAccuracyLabel,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              onTap: b.locating ? null : widget.onUseCurrentLocation,
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  b.openPin();
                },
                icon: const Icon(Icons.map_outlined, size: 19),
                label: const Text('Chọn trên bản đồ'),
              ),
              const Spacer(),
              if (b.searching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 9),
          Text(
            b.query.isEmpty ? 'Địa điểm gần đây' : 'Kết quả tìm kiếm',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final place in b.results)
            PlaceResultRow(
              place: place,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                b.selectPlace(place);
              },
            ),
          if (b.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.error!, style: const TextStyle(color: muted)),
                  TextButton(
                    onPressed: () => b.updateQuery(b.query),
                    child: const Text('Thử lại tìm kiếm'),
                  ),
                ],
              ),
            ),
          if (!b.searching && b.results.isEmpty && b.error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                b.query.isEmpty
                    ? 'Nhập tên đường, số nhà hoặc địa điểm tại Việt Nam.'
                    : 'Không có địa điểm phù hợp. Thêm phường/thành phố hoặc chọn trên bản đồ.',
                style: const TextStyle(color: muted),
              ),
            ),
          if (b.searching && b.results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Đang tìm địa điểm…', style: TextStyle(color: muted)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}
