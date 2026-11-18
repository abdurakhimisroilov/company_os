import 'package:flutter/foundation.dart';

/// Counts "everything on screen is stale" moments: sign-in, sign-out and
/// switching organization. The app rebuilds its state objects and pages for
/// each new value, so no screen keeps data from the previous user or organization.
class AppSession extends ValueNotifier<int> {
  AppSession._() : super(0);
  static final AppSession instance = AppSession._();

  void restart() => value = value + 1;
}
