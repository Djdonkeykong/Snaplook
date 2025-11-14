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
  VideoPlayerController? _loginVideoController;
  VideoPlayerController? _trialVideoController;
  bool _isInitialized = false;
  bool _isLoginVideoInitialized = false;
  bool _isTrialVideoInitialized = false;

  VideoPlayerController? get shareVideoController => _shareVideoController;
  VideoPlayerController? get loginVideoController => _loginVideoController;
  VideoPlayerController? get trialVideoController => _trialVideoController;
  bool get isInitialized => _isInitialized;
  bool get isLoginVideoInitialized => _isLoginVideoInitialized;
  bool get isTrialVideoInitialized => _isTrialVideoInitialized;

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

  Future<void> preloadLoginVideo() async {
    if (_loginVideoController != null) return;

    try {
      _loginVideoController = VideoPlayerController.asset(
        'assets/videos/IntroFinal.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        closedCaptionFile: null,
      );

      await _loginVideoController!.initialize();
      _loginVideoController!.setLooping(true);
      _loginVideoController!.setVolume(0.0);
      _isLoginVideoInitialized = true;

      _loginVideoController!.play();
    } catch (e) {
      print('Error preloading login video: $e');
    }
  }

  void playLoginVideo() {
    if (_loginVideoController != null && _isLoginVideoInitialized) {
      _loginVideoController!.play();
    }
  }

  void pauseLoginVideo() {
    if (_loginVideoController != null && _isLoginVideoInitialized) {
      _loginVideoController!.pause();
    }
  }

  Future<void> preloadTrialVideo() async {
    if (_trialVideoController != null) return;

    try {
      _trialVideoController = VideoPlayerController.asset(
        'assets/videos/IntroFinal.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        closedCaptionFile: null,
      );

      await _trialVideoController!.initialize();
      _trialVideoController!.setLooping(true);
      _trialVideoController!.setVolume(0.0);
      _isTrialVideoInitialized = true;

      _trialVideoController!.play();
    } catch (e) {
      print('Error preloading trial video: $e');
    }
  }

  void playTrialVideo() {
    if (_trialVideoController != null && _isTrialVideoInitialized) {
      _trialVideoController!.play();
    }
  }

  void pauseTrialVideo() {
    if (_trialVideoController != null && _isTrialVideoInitialized) {
      _trialVideoController!.pause();
    }
  }

  void dispose() {
    _shareVideoController?.dispose();
    _shareVideoController = null;
    _isInitialized = false;
    _loginVideoController?.dispose();
    _loginVideoController = null;
    _isLoginVideoInitialized = false;
    _trialVideoController?.dispose();
    _trialVideoController = null;
    _isTrialVideoInitialized = false;
  }
}
