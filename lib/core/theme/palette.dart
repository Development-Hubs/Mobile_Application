import 'package:flutter/material.dart';

/// OneSource Connect colours: Qatar maroon as the single strong colour, deep navy ink, warm neutral surfaces and
/// a little gold for highlights. Status colours are muted so lists stay calm.
class Palette {
  const Palette._();

  // brand
  static const maroon = Color(0xFF8A1538);
  static const maroonBright = Color(0xFFA51D47);
  static const maroonDeep = Color(0xFF5C0C25);
  static const maroonTint = Color(0xFFF7E9EE);
  static const gold = Color(0xFFC49A3A);
  static const goldSoft = Color(0xFFE9D3A0);
  static const sea = Color(0xFF16808F);

  // ink and surfaces (light)
  static const ink = Color(0xFF14192B);
  static const ink2 = Color(0xFF5D6475);
  static const ink3 = Color(0xFF9097A5);
  static const line = Color(0xFFEAE6E1);
  static const canvas = Color(0xFFF6F4F1);
  static const card = Colors.white;

  // ink and surfaces (dark)
  static const night = Color(0xFF0B0F1A);
  static const nightCard = Color(0xFF151A27);
  static const nightLine = Color(0xFF242A3A);

  // legacy names used across screens
  static const navy = Color(0xFF0F1E3D);
  static const navySoft = Color(0xFF3B4A6B);
  static const midnight = Color(0xFF0A0D16);
  static const sand = canvas;
  static const pearl = Colors.white;

  // status
  static const success = Color(0xFF1B8A5A);
  static const warning = Color(0xFFC77D0A);
  static const danger = Color(0xFFC0392B);
  static const info = Color(0xFF2E6BD6);

  static const heroGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [maroonBright, maroon, maroonDeep],
    stops: [0, .55, 1],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [maroonDeep, maroon],
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
      case 'confirmed':
      case 'accepted':
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
      case 'tentative':
      case 'reserved':
        return warning;
      case 'cancelled':
      case 'failed':
      case 'absent':
      case 'rejected':
      case 'expired':
      case 'revoked':
      case 'no_show':
      case 'overdue':
      case 'declined':
        return danger;
      case 'in_progress':
      case 'in':
      case 'en_route':
      case 'new':
      case 'open':
      case 'scheduled':
        return info;
      default:
        return ink2;
    }
  }
}
