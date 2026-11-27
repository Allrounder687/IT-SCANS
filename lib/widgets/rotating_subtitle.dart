import 'dart:async';
import 'package:flutter/material.dart';

class RotatingSubtitle extends StatefulWidget {
  final List<String> texts;
  final TextStyle style;

  const RotatingSubtitle({
    super.key,
    required this.texts,
    required this.style,
  });

  @override
  State<RotatingSubtitle> createState() => _RotatingSubtitleState();
}

class _RotatingSubtitleState extends State<RotatingSubtitle> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Slightly offset initial start so all cards don't flip at the exact same ms.
    final delay = (hashCode % 1000) + 2000;

    unawaited(
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (mounted && widget.texts.length > 1) {
          _timer = Timer.periodic(const Duration(seconds: 3), (_) {
            if (mounted) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % widget.texts.length;
              });
            }
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.texts[_currentIndex % widget.texts.length];

    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              // Only render the incoming child inside the stack so outgoing text
              // never overlaps the active line on narrow screens.
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: SizedBox(
          key: ValueKey<String>(text),
          width: double.infinity,
          child: Text(
            text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ),
      ),
    );
  }
}
