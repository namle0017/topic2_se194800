import '../domain/ride_models.dart';

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
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

/// Only real results learned in this session; no fixed city or address seeds.
List<Place> matchingPlaces(
  Iterable<Place> places,
  String query,
  GeoPoint? near,
) {
  final terms = normalizeQuery(query).split(' ').where((t) => t.isNotEmpty);
  final matches = places.where((p) {
    final haystack = normalizeQuery('${p.name} ${p.address}');
    return terms.every(haystack.contains);
  }).toList();
  if (near != null) {
    matches.sort(
      (a, b) => a.point.distanceTo(near).compareTo(b.point.distanceTo(near)),
    );
  }
  return matches.take(8).toList();
}
