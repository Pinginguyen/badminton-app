import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/ui/bouncy_pressable.dart';
import '../../../core/ui/smash_shockwave_overlay.dart';
import '../badminton_physics_engine.dart';
import '../models/match_score.dart';
import '../widgets/scoreboard_overlay.dart';
import '../widgets/smash_speed_banner.dart';

/// Full-screen camera view with manual scoring and optional measured speed.
class CameraScoreboardScreen extends StatefulWidget {
  const CameraScoreboardScreen({
    super.key,
    required this.initialScore,
    this.smashSpeedKmh,
    this.observedAverageSpeedKmh,
    this.flightDurationSeconds,
    this.onScoreChanged,
  }) : assert(
          (observedAverageSpeedKmh == null) ==
              (flightDurationSeconds == null),
        );

  final MatchScore initialScore;
  final ValueChanged<MatchScore>? onScoreChanged;

  /// Supply only an advisory speed value measured by a separate detector.
  final int? smashSpeedKmh;
  final double? observedAverageSpeedKmh;
  final double? flightDurationSeconds;

  @override
  State<CameraScoreboardScreen> createState() => _CameraScoreboardScreenState();
}

class _CameraScoreboardScreenState extends State<CameraScoreboardScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  late MatchScore _score;
  final List<MatchScore> _undoHistory = [];
  bool _isCameraLoading = true;
  bool _isRecording = false;
  bool _isRecordingAction = false;
  String? _cameraError;
  String? _lastVideoPath;
  int _highestSmashSpeedKmh = 0;
  int _shockwaveTriggerId = 0;
  static const _physicsEngine = BadmintonPhysicsEngine();

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore;
    final initialSpeed = _effectiveSmashSpeedKmh;
    if (initialSpeed != null && initialSpeed > 0) {
      _highestSmashSpeedKmh = initialSpeed;
      _shockwaveTriggerId = 1;
      unawaited(HapticFeedback.heavyImpact());
    }
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    unawaited(WakelockPlus.enable());
    unawaited(_initializeCamera());
  }

  @override
  void didUpdateWidget(covariant CameraScoreboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final speed = _effectiveSmashSpeedKmh;
    if (speed != null && speed > _highestSmashSpeedKmh) {
      _highestSmashSpeedKmh = speed;
      _shockwaveTriggerId++;
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  int? get _effectiveSmashSpeedKmh {
    final averageSpeed = widget.observedAverageSpeedKmh;
    final duration = widget.flightDurationSeconds;
    if (averageSpeed != null && duration != null) {
      return _physicsEngine
          .peakExitVelocityKmh(
            observedAverageVelocityKmh: averageSpeed,
            flightDurationSeconds: duration,
          )
          .round();
    }
    return widget.smashSpeedKmh;
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isRemoteScoreKey = key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause;
    if (!isRemoteScoreKey) return false;

    _addPoint(_score.servingTeam);
    return true;
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isCameraLoading = true;
        _cameraError = null;
      });
    }

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'Không tìm thấy camera trên thiết bị.');
        }
        return;
      }

      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } on CameraException catch (error) {
      if (identical(_cameraController, controller)) {
        _cameraController = null;
      }
      if (controller != null) await controller.dispose();
      if (mounted) setState(() => _cameraError = _cameraErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isCameraLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed &&
        _cameraController == null &&
        !_isCameraLoading) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    if (controller == null) return;
    _cameraController = null;

    try {
      if (controller.value.isRecordingVideo) {
        final video = await controller.stopVideoRecording();
        _lastVideoPath = video.path;
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _cameraError = _cameraErrorMessage(error));
      }
    } finally {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isRecordingAction = false;
        });
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecordingAction) {
      return;
    }

    setState(() => _isRecordingAction = true);
    try {
      if (controller.value.isRecordingVideo) {
        final video = await controller.stopVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _lastVideoPath = video.path;
        });
        _showMessage('Đã lưu video: ${video.path}');
      } else {
        await controller.startVideoRecording();
        if (mounted) setState(() => _isRecording = true);
      }
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isRecordingAction = false);
    }
  }

  void _addPoint(ServingTeam team) {
    if (_score.isMatchComplete) {
      _showMessage('Trận đấu đã kết thúc. Vuốt xuống để sửa điểm.');
      return;
    }
    setState(() {
      _undoHistory.add(_score);
      _score = _score.addPoint(team);
    });
    unawaited(_triggerScoreHaptics());
    widget.onScoreChanged?.call(_score);
  }

  void _undoLastPoint() {
    if (_undoHistory.isEmpty) {
      _showMessage('Chưa có điểm nào để hoàn tác.');
      return;
    }
    setState(() => _score = _undoHistory.removeLast());
    unawaited(_triggerScoreHaptics());
    widget.onScoreChanged?.call(_score);
  }

  Future<void> _triggerScoreHaptics() async {
    await HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 35));
    await HapticFeedback.mediumImpact();
  }

  void _onTapUp(TapUpDetails details, double width) {
    _addPoint(
      details.localPosition.dx < width / 2
          ? ServingTeam.teamA
          : ServingTeam.teamB,
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) > 400) _undoLastPoint();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _cameraErrorMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' =>
        'Quyền camera bị từ chối. Hãy cho phép camera trong phần Cài đặt.',
      'CameraAccessDeniedWithoutPrompt' =>
        'Quyền camera đã bị chặn. Hãy bật quyền trong phần Cài đặt.',
      'CameraAccessRestricted' => 'Thiết bị đang giới hạn quyền dùng camera.',
      _ => 'Không thể khởi động camera (${error.code}). ${error.description ?? ''}',
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) unawaited(controller.dispose());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: SmashShockwaveOverlay(
        triggerId: _shockwaveTriggerId,
        child: Stack(
          fit: StackFit.expand,
          children: [
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onTapUp(details, constraints.maxWidth),
              onVerticalDragEnd: _onVerticalDragEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraView(),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 104,
                    child: IgnorePointer(
                      child: ScoreboardOverlay(score: _score),
                    ),
                  ),
                  if (_effectiveSmashSpeedKmh case final speed?)
                    Positioned(
                      top: 104,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(child: SmashSpeedBanner(speedKmh: speed)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.sports_tennis, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE MATCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Tải lại camera',
                      onPressed: _isCameraLoading ||
                              _cameraController?.value.isInitialized == true
                          ? null
                          : () => unawaited(_initializeCamera()),
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'CHẠM TRÁI: A  •  CHẠM PHẢI: B  •  VUỐT XUỐNG: HOÀN TÁC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RecordButton(
                      isRecording: _isRecording,
                      enabled: !_isRecordingAction &&
                          _cameraController?.value.isInitialized == true,
                      onPressed: _toggleRecording,
                    ),
                    if (_score.isMatchComplete) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(_score),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('XÁC NHẬN KẾT THÚC'),
                        ),
                      ),
                    ],
                    if (_lastVideoPath != null) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Video đã ghi được lưu trên thiết bị',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (controller?.value.isInitialized == true) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = controller!.value.previewSize!;
          final screenAspectRatio =
              constraints.maxWidth / constraints.maxHeight;
          final previewAspectRatio = previewSize.height / previewSize.width;
          final scale = previewAspectRatio < screenAspectRatio
              ? screenAspectRatio / previewAspectRatio
              : previewAspectRatio / screenAspectRatio;

          return ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(controller)),
            ),
          );
        },
      );
    }

    if (_isCameraLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42D6C5)),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 42),
            const SizedBox(height: 14),
            Text(
              _cameraError ?? 'Camera chưa sẵn sàng.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(_initializeCamera()),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.enabled,
    required this.onPressed,
  });

  final bool isRecording;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? Colors.white54
        : isRecording
            ? Colors.white
            : const Color(0xFF111827);
    return BouncyPressable(
      onPressed: enabled ? onPressed : null,
      enabled: enabled,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.white12
              : isRecording
                  ? const Color(0xFFD83443)
                  : Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: foreground.withOpacity(0.16),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Text(
              isRecording ? 'DỪNG GHI HÌNH' : 'GHI HÌNH TRẬN ĐẤU',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
