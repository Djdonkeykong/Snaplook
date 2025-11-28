import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/src/orchestrator/analysis/analysis_to_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../home/domain/providers/image_provider.dart';
import 'detection_page.dart';

class CameraCapturePage extends ConsumerStatefulWidget {
  const CameraCapturePage({super.key});

  @override
  ConsumerState<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends ConsumerState<CameraCapturePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingCapture = false;

  Future<CaptureRequest> _buildCaptureRequest(List<Sensor> sensors) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sensor = sensors.first;
    final filePath = '${directory.path}/snaplook_camera_$timestamp.jpg';

    return SingleCaptureRequest(filePath, sensor);
  }

  Future<void> _onMediaCaptureEvent(MediaCapture mediaCapture) async {
    if (!mounted || !mediaCapture.isPicture) return;

    if (mediaCapture.status == MediaCaptureStatus.failure) {
      setState(() => _isProcessingCapture = false);
      _showSnack('Camera error. Please try again.');
      return;
    }

    if (mediaCapture.status != MediaCaptureStatus.success) return;

    final path = mediaCapture.captureRequest.when(
      single: (single) => single.file?.path,
      multiple: (multiple) => multiple.fileBySensor.values
          .firstWhere((file) => file != null, orElse: () => null)
          ?.path,
    );

    if (path == null) {
      setState(() => _isProcessingCapture = false);
      _showSnack('Could not save photo.');
      return;
    }

    ref.read(selectedImagesProvider.notifier).setImage(XFile(path));

    await Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DetectionPage(searchType: 'camera'),
      ),
    );
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      ref.read(selectedImagesProvider.notifier).setImage(image);

      await Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DetectionPage(searchType: 'photos'),
        ),
      );
    } catch (e) {
      _showSnack('Error opening gallery: $e');
    }
  }

  Widget _buildSpinner() {
    return const Center(
      child: CupertinoActivityIndicator(
        radius: 18,
        color: Colors.white,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onShutter(CameraState cameraState) async {
    if (_isProcessingCapture) return;

    cameraState.when(
      onPhotoMode: (photoState) async {
        setState(() => _isProcessingCapture = true);
        await photoState.takePhoto(onPhotoFailed: (error) {
          if (!mounted) return;
          setState(() => _isProcessingCapture = false);
          _showSnack('Could not capture photo.');
        });
      },
      onPreparingCamera: (_) {
        _showSnack('Camera is getting ready...');
      },
    );
  }

  Future<void> _toggleFlash(CameraState cameraState) async {
    final config = cameraState.sensorConfig;
    FlashMode next;
    switch (config.flashMode) {
      case FlashMode.none:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
        next = FlashMode.on;
        break;
      case FlashMode.on:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.none;
        break;
    }
    await config.setFlashMode(next);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera(CameraState state) async {
    await state.switchCameraSensor(
      aspectRatio: state.sensorConfig.aspectRatio,
      zoom: state.sensorConfig.zoom,
      flash: state.sensorConfig.flashMode,
    );
    if (mounted) setState(() {});
  }

  Widget _buildTopBar(CameraState state) {
    final flashMode = state.sensorConfig.flashMode;
    final flashIcon = switch (flashMode) {
      FlashMode.none => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      FlashMode.on => Icons.flash_on,
      FlashMode.always => Icons.flashlight_on,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCircleButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          const Spacer(),
          _buildCircleButton(
            icon: flashIcon,
            onTap: () => _toggleFlash(state),
            tooltip: 'Flash',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CameraState state) {
    final isFrontCamera =
        state.sensorConfig.sensors.first.position == SensorPosition.front;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Good light and straight-on angles boost accuracy.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'PlusJakartaSans',
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(
                icon: Icons.collections,
                onTap: _openGallery,
                tooltip: 'Use gallery',
              ),
              _buildCaptureButton(state),
              _buildCircleButton(
                icon: Icons.cameraswitch_rounded,
                onTap: () => _switchCamera(state),
                tooltip: 'Flip camera',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(CameraState state) {
    return GestureDetector(
      onTap: () => _onShutter(state),
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white70, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              spreadRadius: 1,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildCameraOverlay(CameraState state, AnalysisPreview _preview) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x66000000),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(state),
              const Spacer(),
              _buildBottomBar(state),
            ],
          ),
        ),
        if (_isProcessingCapture)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: _buildSpinner(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photo(
          pathBuilder: _buildCaptureRequest,
          mirrorFrontCamera: true,
        ),
        progressIndicator: _buildSpinner(),
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.auto,
          aspectRatio: CameraAspectRatios.ratio_4_3,
        ),
        enablePhysicalButton: true,
        previewFit: CameraPreviewFit.cover,
        onMediaCaptureEvent: _onMediaCaptureEvent,
        builder: (cameraState, preview) {
          if (cameraState is PreparingCameraState) {
            return _buildSpinner();
          }
          return _buildCameraOverlay(cameraState, preview);
        },
        theme: AwesomeTheme(
          bottomActionsBackgroundColor: Colors.transparent,
          buttonTheme: AwesomeButtonTheme(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.12),
            iconSize: 22,
          ),
        ),
      ),
    );
  }
}
