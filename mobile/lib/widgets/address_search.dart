import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/saved_place.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

class AddressSearch extends StatefulWidget {
  /// The destination currently in effect, used for the placeholder hint when
  /// it was set from outside this widget (e.g. by dragging the map pin).
  final AppLocation? current;

  /// The persisted home, or null if none has been saved yet. Drives the home
  /// icon's enabled state.
  final SavedPlace? savedHome;

  /// Fires when the user picks a search result.
  final ValueChanged<SavedPlace> onSelected;

  /// Fires when the user taps '+' to persist the active selection.
  final ValueChanged<SavedPlace> onSaveHome;

  /// Fires when the user taps the home icon to reuse the saved place.
  final ValueChanged<SavedPlace> onSelectHome;

  const AddressSearch({
    super.key,
    required this.current,
    required this.savedHome,
    required this.onSelected,
    required this.onSaveHome,
    required this.onSelectHome,
  });

  @override
  State<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends State<AddressSearch> {
  final _geocoding  = GeocodingService();
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  Timer? _debounce;
  Timer? _focusTimer;
  List<GeocodingResult> _results = [];
  bool _loading = false;
  bool _focused = false;

  /// The place backing the text currently in the field — non-null only while
  /// that text came from an actual selection rather than free typing. This is
  /// what gates the '+' icon.
  SavedPlace? _activePlace;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);

    if (!_focusNode.hasFocus) {
      // BUG FIX: Clearing results immediately on focus-loss fires BEFORE the
      // ListTile.onTap callback completes, unmounting the tile and swallowing
      // the tap. A short delay lets the tap gesture finish first.
      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _results = []);
        }
      });
    } else {
      _focusTimer?.cancel();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();

    // Free typing invalidates any prior selection — the text no longer
    // corresponds to a resolved coordinate, so '+' must go inert.
    if (_activePlace != null) setState(() => _activePlace = null);

    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final (:results, :error) = await _geocoding.searchPlaces(query);
      if (!mounted) return;
      setState(() { _results = results; _loading = false; });
    });
  }

  void _select(GeocodingResult r) {
    // Cancel any pending focus-loss clear so it doesn't race with this call.
    _focusTimer?.cancel();
    final place = SavedPlace(label: r.shortName, location: r.location);
    widget.onSelected(place);
    // Assigning .text does not re-enter _onChanged, so _activePlace survives.
    _controller.text = place.label;
    _focusNode.unfocus();
    setState(() { _activePlace = place; _results = []; });
  }

  void _saveActivePlace() {
    final place = _activePlace;
    if (place == null) return;
    widget.onSaveHome(place);
  }

  void _useSavedHome() {
    final saved = widget.savedHome;
    if (saved == null) return;
    _focusTimer?.cancel();
    _controller.text = saved.label;
    _focusNode.unfocus();
    setState(() { _activePlace = saved; _results = []; });
    widget.onSelectHome(saved);
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHint = widget.current != null && !_focused && _controller.text.isEmpty;
    final hasSaved = widget.savedHome != null;

    // Saving is only meaningful for a resolved place that isn't already the
    // stored home — re-saving an identical place is a no-op write, so the
    // affordance goes inert rather than offering a misleading "Saved" toast.
    final canSave = _activePlace != null && _activePlace != widget.savedHome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Text input ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: showHint ? widget.current.toString() : 'Search address…',
                    hintStyle: TextStyle(
                      color: showHint ? AppTheme.textPrimary : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    isDense: true,
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.accent),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onChanged,
                ),
              ),

              // ── Trailing actions ───────────────────────────────────────
              _ActionIcon(
                icon: Icons.add_rounded,
                enabled: canSave,
                tooltip: canSave
                    ? 'Save as home'
                    : _activePlace != null
                        ? 'Already your saved home'
                        : 'Pick an address first',
                onTap: _saveActivePlace,
              ),
              _ActionIcon(
                icon: Icons.home_rounded,
                enabled: hasSaved,
                tooltip: hasSaved
                    ? 'Use saved home — ${widget.savedHome!.label}'
                    : 'No saved home yet',
                onTap: _useSavedHome,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),

        // ── Results dropdown ───────────────────────────────────────────────
        // BUG FIX: Use Material (not Container+BoxDecoration) as the wrapper
        // so ListTile has a proper Material ancestor for ink ripples.
        // A plain Container compiles to DecoratedBox which hides ink effects
        // and can swallow taps on some platforms.
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: AppTheme.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.border),
                ),
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        title: Text(
                          r.shortName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13),
                        ),
                        onTap: () => _select(r),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Compact tappable icon for the search bar's trailing action area. Renders in
/// accent when [enabled] and muted grey otherwise, with taps inert while
/// disabled.
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
