import 'package:duri_care/features/home/home_route.dart';
import 'package:duri_care/features/login/login_route.dart';
import 'package:duri_care/features/onboarding/onboarding_route.dart';
import 'package:duri_care/features/splashscreen/splashscreen_view.dart';
import 'package:get/get.dart';

abstract class AppPages {
  static String initial = SplashscreenView.route;

  static final List<GetPage<dynamic>> routes = [
    ...onboardingRoute,
    ...loginRoute,
    ...homeRoute,
  ];
}