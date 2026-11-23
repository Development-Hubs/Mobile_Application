import 'package:flutter/material.dart';

/// OneSource Connect brand colours: Qatar maroon, deep navy and desert gold.
class Palette {
  const Palette._();

  static const maroon = Color(0xFF8A1538);
  static const maroonBright = Color(0xFFB0204F);
  static const maroonDeep = Color(0xFF5E0B26);
  static const navy = Color(0xFF0F1E3D);
  static const navySoft = Color(0xFF1C2E57);
  static const midnight = Color(0xFF070F22);
  static const gold = Color(0xFFC8A24A);
  static const goldSoft = Color(0xFFE6CF8F);
  static const sand = Color(0xFFF6F1E7);
  static const pearl = Color(0xFFFBFAF7);
  static const sea = Color(0xFF1F7A8C);

  static const success = Color(0xFF1E8E5A);
  static const warning = Color(0xFFD98E04);
  static const danger = Color(0xFFC62828);
  static const info = Color(0xFF2F6FDE);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [maroonBright, maroon, navy],
    stops: [0, .45, 1],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnight, navy, maroonDeep],
    stops: [0, .55, 1],
  );

  static const goldGradient = LinearGradient(colors: [goldSoft, gold]);

  /// Colour for a status word used across modules (case status, trip status, attendance…).
  static Color forStatus(String? s) {
    switch (s) {
      case 'resolved':
      case 'closed':
      case 'completed':
      case 'present':
      case 'approved':
      case 'issued':
      case 'active':
      case 'enrolled':
      case 'checked_in':
      case 'out':
      case 'dropped':
      case 'onboard':
        return success;
      case 'late':
      case 'awaiting_requester':
      case 'awaiting_internal':
      case 'pending':
      case 'waitlisted':
      case 'attempted':
      case 'submitted':
      case 'break':
      case 'due':
        return warning;
      case 'cancelled':
      case 'failed':
      case 'absent':
      case 'rejected':
      case 'expired':
      case 'revoked':
      case 'no_show':
      case 'overdue':
        return danger;
      case 'in_progress':
      case 'in':
      case 'en_route':
      case 'accepted':
      case 'new':
      case 'open':
        return info;
      default:
        return navySoft;
    }
  }
}
