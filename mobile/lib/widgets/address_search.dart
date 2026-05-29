import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';

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
  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _loading = false;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      final results = await _api.searchPlaces(q);
      if (mounted) setState(() { _results = results; _loading = false; });
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
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search address…',
            suffixIcon: _loading ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ) : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onChanged,
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
                  final short = r.displayName.split(',').take(3).join(', ');
                  return ListTile(
                    title: Text(short, style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      widget.onSelected(AppLocation(lat: r.lat, long: r.lon));
                      _controller.clear();
                      setState(() => _results = []);
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
