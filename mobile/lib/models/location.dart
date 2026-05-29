class AppLocation {
  final double lat;
  final double long;

  const AppLocation({required this.lat, required this.long});

  factory AppLocation.fromJson(Map<String, dynamic> json) =>
      AppLocation(lat: (json['lat'] as num).toDouble(), long: (json['long'] as num).toDouble());

  Map<String, dynamic> toJson() => {'lat': lat, 'long': long};

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}';
}
