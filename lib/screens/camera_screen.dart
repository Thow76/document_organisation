import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/image_service.dart';
import '../theme/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _isInitialised = false;
  String? _errorMessage;

  final ImageService _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_currentCameraIndex]);
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      setState(() {
        _errorMessage = status.isPermanentlyDenied
            ? 'Camera permission permanently denied. Please enable it in Settings.'
            : 'Camera permission is required to capture documents.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available on this device.');
        return;
      }
      await _initCameraController(_cameras[_currentCameraIndex]);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialise camera: $e');
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) {
        setState(() => _isInitialised = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialise camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isInitialised = false;
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    });

    await _controller?.dispose();
    await _initCameraController(_cameras[_currentCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final savedPath = await _imageService.saveAndCompressImage(xFile.path);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/categorize',
          arguments: savedPath,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
        title: const Text(
          'AI Document Detection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.amber : AppColors.textPrimary,
            ),
            onPressed: _isInitialised ? _toggleFlash : null,
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : !_isInitialised
          ? const Center(child: CircularProgressIndicator())
          : _buildCameraView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _initCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                // Document frame guide overlay
                _buildFrameGuide(),
                // Guide text at the bottom of the preview
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Position document within frame',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom controls
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildFrameGuide() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth * 0.85;
        final frameHeight = frameWidth * 1.35; // ~A4 proportion
        return CustomPaint(
          size: Size(frameWidth, frameHeight),
          painter: _DashedRectPainter(),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: AppColors.primaryBackground,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery placeholder
          IconButton(
            icon: const Icon(
              Icons.photo_library,
              color: AppColors.textPrimary,
              size: 30,
            ),
            onPressed: () {
              // Placeholder — gallery picker not yet implemented
            },
            tooltip: 'Gallery',
          ),
          // Capture button
          GestureDetector(
            onTap: _isCapturing ? null : _capturePhoto,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: _isCapturing ? Colors.grey : Colors.white,
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primaryBackground,
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          // Camera flip button
          IconButton(
            icon: const Icon(
              Icons.cameraswitch,
              color: AppColors.textPrimary,
              size: 30,
            ),
            onPressed: _cameras.length > 1 ? _flipCamera : null,
            tooltip: 'Switch camera',
          ),
        ],
      ),
    );
  }
}

/// Paints a dashed rectangle overlay as a document positioning guide.
class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(140)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 10.0;
    const dashSpace = 6.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw each side as dashes
    _drawDashedLine(
      canvas,
      paint,
      rect.topLeft,
      rect.topRight,
      dashWidth,
      dashSpace,
    );
    _drawDashedLine(
      canvas,
      paint,
      rect.topRight,
      rect.bottomRight,
      dashWidth,
      dashSpace,
    );
    _drawDashedLine(
      canvas,
      paint,
      rect.bottomRight,
      rect.bottomLeft,
      dashWidth,
      dashSpace,
    );
    _drawDashedLine(
      canvas,
      paint,
      rect.bottomLeft,
      rect.topLeft,
      dashWidth,
      dashSpace,
    );

    // Draw corner accents (solid L-shaped marks)
    final cornerPaint = Paint()
      ..color = Colors.white.withAlpha(220)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;

    // Top-left
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left + cornerLen, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left, rect.top + cornerLen),
      cornerPaint,
    );
    // Top-right
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right - cornerLen, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right, rect.top + cornerLen),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left + cornerLen, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left, rect.bottom - cornerLen),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right - cornerLen, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right, rect.bottom - cornerLen),
      cornerPaint,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashWidth,
    double dashSpace,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = (dx * dx + dy * dy).toDouble();
    final totalLength = length > 0 ? length : 1.0;
    final dist = totalLength != 1.0
        ? (dx.abs() > dy.abs() ? dx.abs() : dy.abs())
        : 0.0;
    final dirX = dist > 0 ? dx / dist : 0.0;
    final dirY = dist > 0 ? dy / dist : 0.0;

    var drawn = 0.0;
    var drawing = true;
    while (drawn < dist) {
      final segLen = drawing ? dashWidth : dashSpace;
      final end2 = drawn + segLen > dist ? dist : drawn + segLen;
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + dirX * drawn, start.dy + dirY * drawn),
          Offset(start.dx + dirX * end2, start.dy + dirY * end2),
          paint,
        );
      }
      drawn = end2;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
