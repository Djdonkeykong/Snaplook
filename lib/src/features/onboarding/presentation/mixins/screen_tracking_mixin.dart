import 'package:flutter/material.dart';
import '../../../../services/analytics_service.dart';
import '../../../../../shared/navigation/route_observer.dart';

mixin ScreenTrackingMixin<T extends StatefulWidget> on State<T>, RouteAware {
  String get screenName;

  void _trackScreenView() {
    AnalyticsService().trackScreenView(screenName);
    debugPrint('[ScreenTracking] Screen viewed: $screenName');
  }

  @override
  void didPush() {
    super.didPush();
    _trackScreenView();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _trackScreenView();
  }
}
