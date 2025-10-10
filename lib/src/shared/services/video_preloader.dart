import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class VideoPreloader {
  static VideoPreloader? _instance;
  static VideoPreloader get instance => _instance ??= VideoPreloader._();

  VideoPreloader._();

  VideoPlayerController? _shareVideoController;
  bool _isInitialized = false;

  VideoPlayerController? get shareVideoController => _shareVideoController;
  bool get isInitialized => _isInitialized;

  Future<void> preloadShareVideo() async {
    if (_shareVideoController != null) return;

    try {
      _shareVideoController = VideoPlayerController.asset(
        'assets/videos/snaplook-share-video-finished-v3.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        closedCaptionFile: null,
      );

      await _shareVideoController!.initialize();
      _shareVideoController!.setLooping(true);
      _shareVideoController!.setVolume(0.0);
      _isInitialized = true;

      // Start playing immediately to warm up the video
      _shareVideoController!.play();
    } catch (e) {
      print('Error preloading share video: $e');
    }
  }

  void playShareVideo() {
    if (_shareVideoController != null && _isInitialized) {
      _shareVideoController!.play();
    }
  }

  void pauseShareVideo() {
    if (_shareVideoController != null && _isInitialized) {
      _shareVideoController!.pause();
    }
  }

  void dispose() {
    _shareVideoController?.dispose();
    _shareVideoController = null;
    _isInitialized = false;
  }
}