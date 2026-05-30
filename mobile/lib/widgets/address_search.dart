import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/geocoding_service.dart';

class AddressSearch extends StatefulWidget {
  final String label;
  final AppLocation? current;
  final ValueChanged<AppLocation> onSelected;

  const AddressSearch({
    super.key,
    required this.label,
    required this.current,
    required this.onSelected,
  });

  @override
  State<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends State<AddressSearch> {
  final _geocoding = GeocodingService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodingResult> _results = [];
  bool _loading = false;
  String? _errorMessage;

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = []; _errorMessage = null; });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() { _loading = true; _errorMessage = null; });

      final (:results, :error) = await _geocoding.searchPlaces(query);

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _errorMessage = error != null ? 'Search unavailable — check connection' : null;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search address…',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onChanged,
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        if (_results.isNotEmpty)
          Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    title: Text(r.shortName,
                        style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      widget.onSelected(r.location);
                      _controller.clear();
                      setState(() { _results = []; });
                    },
                  );
                },
              ),
            ),
          ),
        if (widget.current != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.current.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
