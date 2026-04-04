import 'dart:async';

import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _videoAsset = 'assets/video/Trust_Splash.mp4';
  static const _fallbackDuration = Duration(seconds: 15);

  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    _fallbackTimer = Timer(_fallbackDuration, _goToLogin);
    final controller = VideoPlayerController.asset(_videoAsset);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.play();
      controller.addListener(_handleVideoProgress);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _goToLogin();
    }
  }

  void _handleVideoProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero && position >= duration) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted || _navigated) {
      return;
    }

    _navigated = true;
    _fallbackTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_handleVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isReady
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
