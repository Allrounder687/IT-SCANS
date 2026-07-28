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
    // Slightly offset the initial timer so all cards don't animate at the exact same millisecond
    final delay = (hashCode % 1000) + 2000;
    
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (mounted) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % widget.texts.length;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        widget.texts[_currentIndex],
        key: ValueKey<String>(widget.texts[_currentIndex]),
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
