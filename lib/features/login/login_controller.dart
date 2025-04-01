import 'package:duri_care/core/utils/helpers/dialog_helper.dart';
import 'package:duri_care/features/auth/auth_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final isPasswordVisible = true.obs;
  final isLoading = false.obs;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void clearForm() {
    emailController.clear();
    passwordController.clear();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  Future<void> loginWithEmail(
    String email,
    String password,
    GlobalKey<FormState> dynamicFormKey,
  ) async {
    if (!dynamicFormKey.currentState!.validate()) return;
    try {
      isLoading.value = true;
      await _auth.login(email, password);
      Get.toNamed('/home');
      DialogHelper.showSuccessDialog(
        'Selamat Datang di Aplikasi Duri Care',
        title: 'Berhasil Masuk',
      );
    } catch (e) {
      if (e.toString().contains('invalid_credentials')) {
        DialogHelper.showErrorDialog(
          'Email atau password salah',
          title: 'Gagal Masuk',
        );
      } else if (e.toString().contains('user-not-found')) {
        DialogHelper.showErrorDialog(
          'Akun tidak ditemukan',
          title: 'Gagal Masuk',
        );
      } else {
        DialogHelper.showErrorDialog(e.toString(), title: 'Gagal Masuk');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await DialogHelper.showConfirmationDialog(
      'Apakah Anda yakin ingin keluar dari aplikasi?',
      'Keluar',
      'OK',
      'Batal',
      () async {
        Get.back();
        try {
          await _auth.logout();
          Get.offAllNamed('/login');
        } catch (e) {
          DialogHelper.showErrorDialog(
            'Error logging out: ${e.toString()}',
            title: 'Gagal Keluar',
            onConfirm: () => Get.back(),
          );
        }
      },
      () => Get.back(),
    );
  }

  Future<void> resetPassword(String email) async {
    try {
      DialogHelper.showSuccessDialog(
        'Reset password link has been sent to your email',
        title: 'txt_reset_password'.tr,
      );
    } catch (e) {
      DialogHelper.showErrorDialog(
        e.toString(),
        title: 'txt_reset_password_failed'.tr,
      );
    }
  }

  String? validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (email.isEmpty) {
      return 'Email tidak boleh kosong';
    } else if (!emailRegex.hasMatch(email)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    return null;
  }
}
