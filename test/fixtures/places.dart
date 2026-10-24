import 'package:map_lab/features/booking/domain/ride_models.dart';

const demoPickup = Place(
  id: 'opera',
  name: 'Nhà hát Thành phố',
  address: '07 Công trường Lam Sơn, TP. Hồ Chí Minh',
  point: GeoPoint(10.7767, 106.7033),
);

const demoPlaces = [
  Place(
    id: 'landmark',
    name: 'Landmark 81',
    address: '720A Điện Biên Phủ, Bình Thạnh',
    point: GeoPoint(10.7951, 106.7218),
  ),
  Place(
    id: 'airport',
    name: 'Sân bay Tân Sơn Nhất',
    address: 'Nhà ga quốc nội · đường Trường Sơn',
    point: GeoPoint(10.8138, 106.6627),
  ),
  Place(
    id: 'market',
    name: 'Chợ Bến Thành',
    address: 'Lê Lợi, Bến Thành, TP. Hồ Chí Minh',
    point: GeoPoint(10.7725, 106.6980),
  ),
  Place(
    id: 'palace',
    name: 'Dinh Độc Lập',
    address: '135 Nam Kỳ Khởi Nghĩa, TP. Hồ Chí Minh',
    point: GeoPoint(10.7770, 106.6953),
  ),
  Place(
    id: 'museum',
    name: 'Bảo tàng Chứng tích Chiến tranh',
    address: '28 Võ Văn Tần, TP. Hồ Chí Minh',
    point: GeoPoint(10.7794, 106.6921),
  ),
  Place(
    id: 'crescent',
    name: 'Crescent Mall',
    address: '101 Tôn Dật Tiên, Tân Phú',
    point: GeoPoint(10.7286, 106.7188),
  ),
  demoPickup,
];

String normalizeQuery(String input) {
  var result = input.trim().toLowerCase();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  groups.forEach((letter, variants) {
    for (final variant in variants.split('')) {
      result = result.replaceAll(variant, letter);
    }
  });
  return result;
}

List<Place> localPlaces(String query) {
  final normalized = normalizeQuery(query);
  if (normalized.isEmpty) return demoPlaces.take(3).toList();
  final terms = normalized.split(RegExp(r'\s+'));
  return demoPlaces.where((place) {
    final haystack = normalizeQuery('${place.name} ${place.address}');
    return terms.every(haystack.contains);
  }).toList();
}
