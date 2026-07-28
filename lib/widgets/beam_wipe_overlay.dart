import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class BeamWipeOverlay extends StatefulWidget {
  final Widget child;

  const BeamWipeOverlay({super.key, required this.child});

  @override
  State<BeamWipeOverlay> createState() => _BeamWipeOverlayState();
}

class _BeamWipeOverlayState extends State<BeamWipeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationComplete = true;
        });
      }
    });

    // Start animation immediately
    _controller.forward();
    
    // Trigger haptic in middle of animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationComplete) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final screenHeight = MediaQuery.of(context).size.height;
            // The box starts at the top (covering everything) and moves down.
            final beamY = _controller.value * screenHeight;
            
            return Positioned(
              top: beamY,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: appBackground,
                  border: Border(
                    top: BorderSide(
                      color: appAccent,
                      width: 3.0,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: appAccent.withValues(alpha: 0.5),
                      blurRadius: 20.0,
                      spreadRadius: 2.0,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
