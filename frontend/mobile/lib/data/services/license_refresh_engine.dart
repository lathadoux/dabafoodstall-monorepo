// path: frontend/mobile/lib/core/services/license_refresh_engine.dart
import 'dart:async';
import 'dart:convert';
//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

enum LicenseSyncState { active, warning, expired, fraud }

class LicenseModel {
  final LicenseSyncState state;
  final int daysRemaining;
  final String shortCode;

  LicenseModel({required this.state, required this.daysRemaining, required this.shortCode});

  LicenseModel copyWith({LicenseSyncState? state, int? daysRemaining, String? shortCode}) {
    return LicenseModel(
      state: state ?? this.state,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      shortCode: shortCode ?? this.shortCode,
    );
  }
}

// 🔑 COUPLAGE INFRASTRUCTURE : Provider Riverpod pour injecter la DFP et la Database
final licenseRefreshProvider = StateNotifierProvider.family<LicenseRefreshEngine, LicenseModel, Map<String, dynamic>>((ref, params) {
  return LicenseRefreshEngine(
    dfp: params['dfp'],
    database: params['database'],
  );
});

class LicenseRefreshEngine extends StateNotifier<LicenseModel> {
  final String dfp;
  final Database database;
  Timer? _heartbeatTimer;

  LicenseRefreshEngine({required this.dfp, required this.database}) 
      : super(LicenseModel(state: LicenseSyncState.active, daysRemaining: 30, shortCode: "000-000-000")) {
    executeSilentRefresh();
    // Heartbeat automatique de synchronisation (15 minutes)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (_) => executeSilentRefresh());
  }

  Future<void> executeSilentRefresh() async {
    try {
      final url = Uri.parse('https://ngrok-free.dev');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-device-dfp': dfp
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        final String expirationCloud = result['date_expiration'];
        final String serverTimeStr = result['server_time'] ?? DateTime.now().toIso8601String();

        final DateTime dateCloud = DateTime.parse(expirationCloud);
        final DateTime serverTime = DateTime.parse(serverTimeStr);

        // Protection Anti-Triche Horaire
        if (DateTime.now().isBefore(serverTime.subtract(const Duration(minutes: 5)))) {
          state = state.copyWith(state: LicenseSyncState.fraud);
          return;
        }

        await database.update(
          'term_params',
          {'date_expiration': expirationCloud},
          where: 'device_fingerprint = ?',
          whereArgs: [dfp],
        );

        _evaluateTimeGaps(dateCloud);
      } else if (response.statusCode == 402) {
        state = state.copyWith(state: LicenseSyncState.expired);
      }
    } catch (e) {
      _loadLocalParams();
    }
  }

  Future<void> _loadLocalParams() async {
    final List<Map<String, dynamic>> maps = await database.query('term_params', limit: 1);
    if (maps.isNotEmpty) {
      final String codeCourt = maps.first['code_activation_court'] ?? "000-000-000";
      state = state.copyWith(shortCode: codeCourt);
      final String? expLocal = maps.first['date_expiration'];
      if (expLocal != null) {
        _evaluateTimeGaps(DateTime.parse(expLocal));
      }
    }
  }

  void _evaluateTimeGaps(DateTime expirationDate) {
    final int diff = expirationDate.difference(DateTime.now()).inDays;
    LicenseSyncState status = LicenseSyncState.active;

    if (diff <= 0) {
      status = LicenseSyncState.expired;
    } else if (diff <= 3) {
      status = LicenseSyncState.warning; // 🟠 Déclencheur du bandeau orange
    }

    state = LicenseModel(state: status, daysRemaining: diff, shortCode: state.shortCode);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
