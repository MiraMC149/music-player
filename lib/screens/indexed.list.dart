import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:music_player/models/library.view.dart';
import 'package:music_player/widgets/library.widget.dart';

/// A list with optional A-Z section headers and a slider on the right edge.
///
/// Tap a letter to jump to it, or drag along the slider: the letter under your
/// finger is shown in a bubble and the list follows. Letters with no items are
/// dimmed and jump to the next letter that has some.
///
/// Items must already be sorted so that [letterOf] is non-decreasing
/// ('#' first, then A-Z). Give this widget a new `key` when the sort changes
/// so the scroll position resets.
class IndexedListView extends StatefulWidget {
  const IndexedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.letterOf,
    this.itemExtent = kRowExtent,
    this.headerExtent = 32,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Section letter of item [index]. When null there are no headers and no slider.
  final String Function(int index)? letterOf;

  final double itemExtent;
  final double headerExtent;

  @override
  State<IndexedListView> createState() => _IndexedListViewState();
}

class _Row {
  const _Row.header(this.letter) : index = -1;
  const _Row.item(this.index) : letter = null;

  final int index;
  final String? letter;

  bool get isHeader => letter != null;
}

class _IndexedListViewState extends State<IndexedListView> {
  final _controller = ScrollController();
  final _active = ValueNotifier<String?>(null);
  Timer? _hideTimer;
  String _lastShown = '#';

  @override
  void dispose() {
    _hideTimer?.cancel();
    _active.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setActive(String? letter) {
    _hideTimer?.cancel();
    if (letter != null) {
      _lastShown = letter;
      _active.value = letter;
    } else {
      // Keep the bubble visible briefly so a quick tap is still noticeable.
      _hideTimer = Timer(
        const Duration(milliseconds: 350),
        () => _active.value = null,
      );
    }
  }

  /// First letter at or after [letter] that has items, else the last one before it.
  String? _resolve(String letter, Set<String> available) {
    final start = indexLetters.indexOf(letter);
    for (var i = start; i < indexLetters.length; i++) {
      if (available.contains(indexLetters[i])) return indexLetters[i];
    }
    for (var i = start; i >= 0; i--) {
      if (available.contains(indexLetters[i])) return indexLetters[i];
    }
    return null;
  }

  void _jumpTo(String letter, Map<String, double> offsets) {
    final target = _resolve(letter, offsets.keys.toSet());
    if (target == null || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(math.min(max, math.max(0.0, offsets[target]!)));
  }

  @override
  Widget build(BuildContext context) {
    // Flatten items + headers so every row has a known height. That makes the
    // offset of each letter exact, with no extra packages.
    final rows = <_Row>[];
    final offsets = <String, double>{};
    final letterOf = widget.letterOf;
    var y = 0.0;
    String? last;

    for (var i = 0; i < widget.itemCount; i++) {
      final letter = letterOf?.call(i);
      if (letter != null && letter != last) {
        offsets[letter] = y;
        rows.add(_Row.header(letter));
        y += widget.headerExtent;
        last = letter;
      }
      rows.add(_Row.item(i));
      y += widget.itemExtent;
    }

    final list = ListView.builder(
      controller: _controller,
      itemCount: rows.length,
      itemExtentBuilder: (index, _) =>
          rows[index].isHeader ? widget.headerExtent : widget.itemExtent,
      itemBuilder: (context, index) {
        final row = rows[index];
        return row.isHeader
            ? _SectionHeader(row.letter!)
            : widget.itemBuilder(context, row.index);
      },
    );

    if (letterOf == null) return list;

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: list),
            SizedBox(
              width: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AlphabetIndexBar(
                  available: offsets.keys.toSet(),
                  onLetter: (letter) => _jumpTo(letter, offsets),
                  onActive: _setActive,
                ),
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: _active,
                builder: (context, letter, _) => AnimatedOpacity(
                  opacity: letter == null ? 0 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _lastShown,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surfaceContainerLow,
      child: Text(
        letter,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// The vertical "# A B C ... Z" strip. Reports the letter under the finger.
class AlphabetIndexBar extends StatefulWidget {
  const AlphabetIndexBar({
    super.key,
    required this.available,
    required this.onLetter,
    required this.onActive,
  });

  /// Letters that have at least one item (others are dimmed).
  final Set<String> available;

  /// Called when the touched letter changes.
  final ValueChanged<String> onLetter;

  /// Called with the touched letter, or null when the finger lifts.
  final ValueChanged<String?> onActive;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  String? _last;

  void _select(double dy, double height) {
    final index = (dy / height * indexLetters.length)
        .floor()
        .clamp(0, indexLetters.length - 1);
    final letter = indexLetters[index];
    if (letter == _last) return; // don't re-jump for every pixel of movement
    _last = letter;
    widget.onActive(letter);
    widget.onLetter(letter);
  }

  void _release() {
    _last = null;
    widget.onActive(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _select(d.localPosition.dy, height),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          onVerticalDragStart: (d) => _select(d.localPosition.dy, height),
          onVerticalDragUpdate: (d) => _select(d.localPosition.dy, height),
          onVerticalDragEnd: (_) => _release(),
          onVerticalDragCancel: _release,
          child: Column(
            children: [
              for (final letter in indexLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: style?.copyWith(
                        fontWeight: widget.available.contains(letter)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: widget.available.contains(letter)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}