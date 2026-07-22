import 'location.dart';

/// A coordinate paired with human-readable text for display.
///
/// Deliberately kept separate from [AppLocation], which is the wire format the
/// backend consumes — adding a label there would leak a presentation concern
/// into every `homeLocation` request body.
class SavedPlace {
  final String label;
  final AppLocation location;

  const SavedPlace({required this.label, required this.location});

  /// Fallback for places that carry no address text — a dragged map pin, for
  /// example. Uses [AppLocation.toString]'s truncated lat/long pair.
  factory SavedPlace.fromCoordinates(AppLocation location) =>
      SavedPlace(label: location.toString(), location: location);

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        label: json['label'] as String,
        location: AppLocation.fromJson(
          Map<String, dynamic>.from(json['location'] as Map),
        ),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'location': location.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is SavedPlace &&
      other.label == label &&
      other.location.lat == location.lat &&
      other.location.long == location.long;

  @override
  int get hashCode => Object.hash(label, location.lat, location.long);

  @override
  String toString() => label;
}
