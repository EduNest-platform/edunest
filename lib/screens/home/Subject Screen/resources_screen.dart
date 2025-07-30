import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../services/files_service.dart';
import '../../../services/error_message_service.dart';
import '../resources/notes_screen.dart';
import '../resources/pyq_screen.dart';
import '../resources/assignments_screen.dart';
import '../resources/lab_manuals_screen.dart';
import '../resources/code_screen.dart';
import '../resources/others_screen.dart';
import '../../../widgets/custom_app_bar.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:math';
import 'dart:ui';

class ResourcesScreen extends StatefulWidget {
  final Subject subject;

  const ResourcesScreen({super.key, required this.subject});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, int> _fileStats = {};
  late AnimationController _refreshController;

  final List<Map<String, dynamic>> _resourceCategories = [
    {
      'name': 'Notes',
      'subtitle': 'Study materials & lectures',
      'icon': Icons.description_rounded,
      'color': Colors.blue,
      'type': 'notes',
      'screen': NotesScreen,
    },
    {
      'name': 'PYQ',
      'subtitle': 'Previous year questions',
      'icon': Icons.quiz_rounded,
      'color': Colors.purple,
      'type': 'pyq',
      'screen': PYQScreen,
    },
    {
      'name': 'Assignments',
      'subtitle': 'Tasks & submissions',
      'icon': Icons.assignment_rounded,
      'color': Colors.orange,
      'type': 'assignment',
      'screen': AssignmentsScreen,
    },
    {
      'name': 'Lab Manuals',
      'subtitle': 'Practical experiments',
      'icon': Icons.science_rounded,
      'color': Colors.green,
      'type': 'lab_manuals',
      'screen': LabManualsScreen,
    },
    {
      'name': 'Code',
      'subtitle': 'Examples & implementations',
      'icon': Icons.code_rounded,
      'color': Colors.teal,
      'type': 'code',
      'screen': CodeScreen,
    },
    {
      'name': 'Others',
      'subtitle': 'Additional resources',
      'icon': Icons.folder_rounded,
      'color': Colors.indigo,
      'type': 'other',
      'screen': OthersScreen,
    },
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadFileStats();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadFileStats() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final stats = await FilesService.getFileStats(widget.subject.id);

      setState(() {
        _fileStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildNavbarItem(int index) {
    final category = _resourceCategories[index];
    final isSelected = _selectedIndex == index;
    final fileCount = _fileStats[category['type']] ?? 0;

    final isDesktop =
        kIsWeb ||
        [
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        ].contains(Theme.of(context).platform);

    // Add extra margin to the first and last tab for alignment
    EdgeInsets margin = EdgeInsets.only(
      left: index == 0 ? (isDesktop ? 32 : 16) : (isDesktop ? 12 : 6),
      right:
          index == _resourceCategories.length - 1
              ? (isDesktop ? 32 : 16)
              : (isDesktop ? 12 : 6),
    );

    double fontSize = isDesktop ? 17 : 15;
    double iconSize = isDesktop ? 26 : 22;
    double verticalPad = isDesktop ? 16 : 12;
    double horizontalPad = isDesktop ? 22 : 14;
    double badgeFontSize = isDesktop ? 14 : 12;
    double badgePadH = isDesktop ? 12 : 8;
    double badgePadV = isDesktop ? 5 : 3;

    return MouseRegion(
      onEnter: isDesktop ? (_) => setState(() => _hoveredIndex = index) : null,
      onExit: isDesktop ? (_) => setState(() => _hoveredIndex = null) : null,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder:
              (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
          child: Container(
            key: ValueKey(isSelected),
            margin: margin,
            constraints: BoxConstraints(minHeight: isDesktop ? 54 : 44),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: verticalPad,
            ),
            decoration: BoxDecoration(
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [
                          category['color'],
                          category['color'].withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color:
                  isSelected
                      ? null
                      : (_hoveredIndex == index && isDesktop
                          ? Colors.grey.shade200
                          : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(isDesktop ? 32 : 28),
              border: Border.all(
                color: isSelected ? category['color'] : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: category['color'].withValues(alpha: 0.13),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    category['icon'],
                    color: isSelected ? Colors.white : category['color'],
                    size: iconSize,
                  ),
                  SizedBox(width: isDesktop ? 14 : 10),
                  Text(
                    category['name'],
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (fileCount > 0 && !isDesktop) ...[
                    SizedBox(width: isDesktop ? 14 : 10),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: badgePadH,
                        vertical: badgePadV,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : category['color'].withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 14 : 12,
                        ),
                      ),
                      child: Text(
                        fileCount.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : category['color'],
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
  }

  int? _hoveredIndex;

  Widget _buildAppBar() {
    return CustomAppBar(
      title: 'Resources',
      subtitle: 'Subject resources and materials',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _refreshController.value * 6.3,
              child: IconButton(
                onPressed: () async {
                  if (!_refreshController.isAnimating) {
                    _refreshController.forward(from: 0);
                  }
                  _loadFileStats();
                },
                icon: const Icon(Icons.refresh_rounded, size: 24),
                tooltip: 'Refresh',
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _resourceCategories[_selectedIndex];
    final isDesktop =
        kIsWeb ||
        [
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        ].contains(Theme.of(context).platform);

    // Create the appropriate screen widget based on the selected category
    Widget screenWidget;
    switch (selectedCategory['type']) {
      case 'notes':
        screenWidget = NotesScreen(subject: widget.subject);
        break;
      case 'pyq':
        screenWidget = PYQScreen(subject: widget.subject);
        break;
      case 'assignment':
        screenWidget = AssignmentsScreen(subject: widget.subject);
        break;
      case 'lab_manuals':
        screenWidget = LabManualsScreen(subject: widget.subject);
        break;
      case 'code':
        screenWidget = CodeScreen(subject: widget.subject);
        break;
      case 'other':
        screenWidget = OthersScreen(subject: widget.subject);
        break;
      default:
        screenWidget = NotesScreen(subject: widget.subject);
    }

    Widget content = Column(
      children: [
        _buildAppBar(),
        const Divider(height: 1.5, thickness: 1.5),
        Container(
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.025),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isDesktop ? 62 : 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _resourceCategories.length,
            itemBuilder: (context, index) {
              return _buildNavbarItem(index);
            },
          ),
        ),
        Expanded(child: screenWidget),
      ],
    );

    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      );
    }

    Widget body = content;

    if (isDesktop) {
      body = Stack(
        children: [
          // Animated floating blurred circles (blobs)
          Positioned(
            left: 0,
            top: 120,
            child: _AnimatedBlob(
              size: 220,
              color: Colors.blue.withValues(alpha: 0.18),
              blurSigma: 60,
              dx: 0,
              dy: 40,
              duration: 7000,
            ),
          ),
          Positioned(
            right: 0,
            top: 260,
            child: _AnimatedBlob(
              size: 170,
              color: Colors.purple.withValues(alpha: 0.13),
              blurSigma: 50,
              dx: 0,
              dy: -30,
              duration: 9000,
            ),
          ),
          Positioned(
            left: 60,
            bottom: 60,
            child: _AnimatedBlob(
              size: 120,
              color: Colors.teal.withValues(alpha: 0.12),
              blurSigma: 40,
              dx: 0,
              dy: 30,
              duration: 8000,
            ),
          ),
          body,
        ],
      );
    }

    return Scaffold(backgroundColor: Colors.grey.shade50, body: body);
  }
}

class _AnimatedBlob extends StatefulWidget {
  final double size;
  final Color color;
  final double blurSigma;
  final double dx;
  final double dy;
  final int duration;

  const _AnimatedBlob({
    required this.size,
    required this.color,
    required this.blurSigma,
    required this.dx,
    required this.dy,
    required this.duration,
  });

  @override
  State<_AnimatedBlob> createState() => _AnimatedBlobState();
}

class _AnimatedBlobState extends State<_AnimatedBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    )..repeat(reverse: true);
    _moveAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _moveAnim,
      builder: (context, child) {
        final offset = lerpDouble(widget.dx, -widget.dx, _moveAnim.value)!;
        final offsetY = lerpDouble(widget.dy, -widget.dy, _moveAnim.value)!;
        return Transform.translate(
          offset: Offset(offset, offsetY),
          child: child,
        );
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
