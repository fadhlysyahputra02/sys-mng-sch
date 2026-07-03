import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isDark;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.isDark,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _showHint = true;
  Timer? _hintTimer;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _startHintCycle();
  }

  void _startHintCycle() {
    // Show hint for 4 seconds initially, then hide
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });

    // Periodically show it again for 3 seconds every 15 seconds to make it look active
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _showHint = true;
        });
        _hintTimer?.cancel();
        _hintTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showHint = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hintTimer?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeDotColor = const Color(0xFF8B5CF6);
    final inactiveDotColor = widget.isDark ? Colors.white30 : Colors.black26;
    final hintTextColor = widget.isDark ? Colors.white54 : Colors.black45;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 0 && !_isFront) {
                // swipe right -> flip to front
                _toggleCard();
              } else if (details.primaryVelocity! < 0 && _isFront) {
                // swipe left -> flip to back
                _toggleCard();
              }
            }
          },
          onTap: _toggleCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final double value = _animation.value;
              final double angle = value * math.pi;
              final bool isFrontShowing = angle < math.pi / 2;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // 3D perspective depth
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isFrontShowing
                    ? widget.front
                    : Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: widget.back,
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFront ? activeDotColor : inactiveDotColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !_isFront ? activeDotColor : inactiveDotColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedOpacity(
          opacity: _showHint ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Text(
            '← Geser →',
            style: TextStyle(
              fontSize: 9,
              color: hintTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
