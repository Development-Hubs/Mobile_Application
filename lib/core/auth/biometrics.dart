import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Device biometric unlock (Face ID / fingerprint) through the operating system.
///
/// The app never sees, stores or sends a face image or template: the OS answers yes or no.
/// It only unlocks the token already in secure storage; it is not a sign-in to the ERP.
class Biometrics {
  Biometrics([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> unlock(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false));
    } on PlatformException {
      return false;
    }
  }
}
