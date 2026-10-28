import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class SearchInputWithDropdown<T> extends StatefulWidget {
  final String baseUrl;
  final Future<List<T>> Function(String query, String baseUrl) onSearch;
  final Widget Function(T item) itemBuilder;
  final void Function(T item) onItemTap;
  final VoidCallback onTapMore;
  final int maxVisibleResults;
  final String hintText;

  const SearchInputWithDropdown({
    super.key,
    required this.baseUrl,
    required this.onSearch,
    required this.itemBuilder,
    required this.onItemTap,
    required this.onTapMore,
    this.maxVisibleResults = 4,
    this.hintText = 'Search...',
  });

  @override
  State<SearchInputWithDropdown<T>> createState() => _SearchInputWithDropdownState<T>();
}

class _SearchInputWithDropdownState<T> extends State<SearchInputWithDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  bool _isLoading = false;
  List<T> _results = [];
  
  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 8),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No results found',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            // Display limited number of results
                            ..._results.take(widget.maxVisibleResults).map((item) {
                              return InkWell(
                                onTap: () {
                                  _removeOverlay();
                                  widget.onItemTap(item);
                                },
                                child: widget.itemBuilder(item),
                              );
                            }),
                            
                            // Show More Option if results exceed limit
                            if (_results.length > widget.maxVisibleResults) ...[
                              const Divider(height: 1),
                              InkWell(
                                onTap: () {
                                  _removeOverlay();
                                  widget.onTapMore();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Show More',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      _removeOverlay();
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _showOverlay();

    try {
      final fetchedResults = await widget.onSearch(query, widget.baseUrl);
      if (mounted) {
        setState(() {
          _results = fetchedResults;
          _isLoading = false;
        });
        // Re-build overlay with new results
        _overlayEntry?.markNeedsBuild();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _results = [];
        });
        _overlayEntry?.markNeedsBuild();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(TablerIcons.search, color: Colors.grey),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(TablerIcons.x, size: 18, color: Colors.grey),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 1),
          ),
        ),
      ),
    );
  }
}