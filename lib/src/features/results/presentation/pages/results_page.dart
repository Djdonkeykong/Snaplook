import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/results_bottom_sheet.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final List<DetectionResult> results;
  final String? originalImageUrl;

  const ResultsPage({
    super.key,
    required this.results,
    this.originalImageUrl,
  });

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage>
    with SingleTickerProviderStateMixin {
  static const double _minSheetExtent = 0.4;
  static const double _initialSheetExtent = 0.6;
  static const double _maxSheetExtent = 0.85;

  late TabController _tabController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isSheetVisible = false;
  bool _isClosingSheet = false;
  double _currentSheetExtent = _initialSheetExtent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isSheetVisible = true;
      });
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage = ref.watch(selectedImageProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: _TopIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _TopIconButton(
            icon: Icons.share,
            onPressed: _shareResults,
          ),
        ],
      ),
      body: Stack(
        children: [
          _ResultsBackground(
            selectedImage: selectedImage,
            originalImageUrl: widget.originalImageUrl,
          ),
          if (_isSheetVisible) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissResults,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Colors.black.withOpacity(_overlayOpacity),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child:
                    NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    if (!mounted) return false;
                    final extent = notification.extent
                        .clamp(_minSheetExtent, _maxSheetExtent)
                        .toDouble();
                    setState(() => _currentSheetExtent = extent);
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _initialSheetExtent,
                    minChildSize: _minSheetExtent,
                    maxChildSize: _maxSheetExtent,
                    snap: false,
                    expand: false,
                    builder: (context, scrollController) {
                      return ResultsBottomSheetContent(
                        results: widget.results,
                        scrollController: scrollController,
                        onProductTap: _openProduct,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shareResults() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share functionality coming soon!',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  void _openProduct(DetectionResult result) async {
    if (result.purchaseUrl != null) {
      final uri = Uri.parse(result.purchaseUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  double get _overlayOpacity {
    final range = _maxSheetExtent - _minSheetExtent;
    if (range <= 0) return 0.7;
    final normalized =
        ((_currentSheetExtent - _minSheetExtent) / range).clamp(0.0, 1.0);
    return 0.15 + (0.55 * normalized);
  }

  void _dismissResults() {
    if (_isClosingSheet) return;
    _isClosingSheet = true;
    setState(() => _isSheetVisible = false);
    Navigator.of(context).pop();
  }
}

class _ResultsBackground extends StatelessWidget {
  const _ResultsBackground({
    this.selectedImage,
    this.originalImageUrl,
  });

  final XFile? selectedImage;
  final String? originalImageUrl;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (originalImageUrl != null) {
      child = Image.network(
        originalImageUrl!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: frame != null
                ? child
                : Container(color: Colors.black),
          );
        },
        errorBuilder: (context, _, __) => Container(color: Colors.black),
      );
    } else if (selectedImage != null) {
      child = Image.file(
        File(selectedImage!.path),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: frame != null
                ? child
                : Container(color: Colors.black),
          );
        },
      );
    } else {
      child = const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(child: child);
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: icon == Icons.share
            ? const EdgeInsets.fromLTRB(2, 8, 4, 8)
            : const EdgeInsets.all(8),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 18),
      ),
    );
  }
}
