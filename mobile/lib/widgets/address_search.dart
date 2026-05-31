import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

class AddressSearch extends StatefulWidget {
  final AppLocation? current;
  final ValueChanged<AppLocation> onSelected;

  const AddressSearch({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  State<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends State<AddressSearch> {
  final _geocoding = GeocodingService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GeocodingResult> _results = [];
  bool _loading = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
      if (!_focusNode.hasFocus) setState(() => _results = []);
    });
  }

  void _onChanged(String query) {
    _debounce?.cancel();
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
    widget.onSelected(r.location);
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _results = []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.current != null && !_focused && _controller.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: hasLocation
                        ? widget.current.toString()
                        : 'Search address…',
                    hintStyle: TextStyle(
                      color: hasLocation
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13,
                    ),
                    isDense: true,
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accent,
                              ),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.home_rounded,
                  size: 18,
                  color: widget.current != null
                      ? AppTheme.accent
                      : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        // Results dropdown
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppTheme.border),
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
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => _select(r),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
