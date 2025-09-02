import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Added for BackdropFilter

// Centralized update info
const String currentVersion = '1.1.0'; // Update for each release
const String latestJsonUrl =
    'https://raw.githubusercontent.com/Ranojitdas/EduNest-Update/main/latest.json';

class _AnimatedCircle extends StatefulWidget {
  final double size;
  final Color color;
  final Offset start;
  final Offset end;
  final Duration duration;
  final Duration delay;

  const _AnimatedCircle({
    required this.size,
    required this.color,
    required this.start,
    required this.end,
    required this.duration,
    required this.delay,
  });

  @override
  State<_AnimatedCircle> createState() => _AnimatedCircleState();
}

class _AnimatedCircleState extends State<_AnimatedCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _positionAnim = Tween<Offset>(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(
      begin: 0.5,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnim.value.dx,
          top: _positionAnim.value.dy,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WhatsNewDialog extends StatelessWidget {
  // Update this list for each release
  static const List<String> whatsNewItems = [
    "📘 Added Midsem marks section",
    "🔔 Real-time notifications for assignment and midsem marks",
    "🎨 Improved notification screen UI",
    "⚡ Faster loading with caching system",
    "📝 Enhanced roll number and signup process",
    "🐞 Performance improvements and bug fixes",
    "🧪 Testing Unity ads (see About Us page)",
  ];


  const WhatsNewDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(color: Colors.black.withValues(alpha: 0.08)),
        ),
        Center(
          child: SafeArea(
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: const Color(0xFF3A8DFF).withValues(alpha: 0.13),
                  width: 1.4,
                ),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.98),
              elevation: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  minWidth: 320,
                  maxHeight: 700, // Increased height for better visibility
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 32,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Celebratory icon
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF3A8DFF),
                                Color(0xFF6DD5FA),
                                Color(0xFFB2FEFA),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          "What's New in EduNest!",
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ...whatsNewItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6.0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF3A8DFF),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Thank you for using EduNest!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF3A8DFF),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A8DFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check_rounded, size: 22),
                            label: const Text('Close'),
                          ),
                        ),
                      ],
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
