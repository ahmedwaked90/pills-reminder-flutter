import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pills_reminder/core/models/medication_frequency.dart';
import 'package:pills_reminder/core/models/notification_type.dart';
import 'package:pills_reminder/core/models/weekday.dart';
import 'package:pills_reminder/features/medications/data/models/medication_model.dart';

/// Maps a local [MedicationModel] to the backend wire format and back.
///
/// Fields the backend does not model natively ([MedicationModel.amount]
/// as an integer separate from dose-text, `timesPillTaken`,
/// `notificationType`, `monthlyDay`) are packed into the backend's free
/// `notes` column as a JSON blob under a private key, so round-tripping
/// through the server does not lose data.
class MedicationMapper {
  static const _hiddenNotesKey = '__pillsReminderMeta';

  /// Serialize a local model to the JSON shape `/api/medications` and
  /// `/api/sync` accept.
  static Map<String, dynamic> toRemote(
    MedicationModel med, {
    required String clientUuid,
    required DateTime clientUpdatedAt,
    bool deleted = false,
  }) {
    final meta = <String, dynamic>{
      'amount': med.amount,
      'times_pill_taken': med.timesPillTaken,
      'notification_type': med.notificationType?.name,
      'monthly_day': med.monthlyDay?.toIso8601String(),
      'local_id': med.id,
    };

    final payload = <String, dynamic>{
      'client_uuid': clientUuid,
      'name': med.name,
      'frequency': _freqToString(med.frequency),
      'weekdays': (med.selectedDays ?? const [])
          .map(_weekdayToIso)
          .toList(growable: false),
      'times': med.times.map(_fmtTime).toList(growable: false),
      'start_date': _dateOnly(med.monthlyDay ?? DateTime.now()),
      'end_date': null,
      'dose': med.amount?.toString(),
      'notes': jsonEncode({_hiddenNotesKey: meta}),
      'client_updated_at': clientUpdatedAt.toUtc().toIso8601String(),
    };

    if (deleted) payload['deleted'] = true;
    return payload;
  }

  /// Rebuild a local model from a backend record. Requires a local
  /// `id` (the caller either reuses an existing one from sync meta
  /// store, or allocates a new one).
  static MedicationModel fromRemote(
    Map<String, dynamic> json, {
    required int localId,
  }) {
    final meta = _readHiddenMeta(json['notes']);
    final int? amount = meta['amount'] is int
        ? meta['amount'] as int
        : int.tryParse('${meta['amount'] ?? json['dose'] ?? ''}');

    final times = (json['times'] as List? ?? const [])
        .cast<String>()
        .map(_parseTime)
        .toList(growable: false);

    final weekdays = (json['weekdays'] as List? ?? const [])
        .map((e) => _isoToWeekday((e as num).toInt()))
        .toList(growable: false);

    final timesPillTaken = (meta['times_pill_taken'] is List)
        ? (meta['times_pill_taken'] as List).cast<bool>()
        : List<bool>.filled(times.length, false);

    final notifType = _parseNotifType(meta['notification_type'] as String?);

    DateTime? monthlyDay;
    final monthlyDayRaw = meta['monthly_day'];
    if (monthlyDayRaw is String) {
      monthlyDay = DateTime.tryParse(monthlyDayRaw);
    } else {
      final startDate = json['start_date'] as String?;
      if (startDate != null) monthlyDay = DateTime.tryParse(startDate);
    }

    return MedicationModel(
      id: localId,
      name: (json['name'] as String?) ?? '',
      amount: amount,
      times: times,
      timesPillTaken: timesPillTaken.length == times.length
          ? timesPillTaken
          : List<bool>.filled(times.length, false),
      frequency: _freqFromString(json['frequency'] as String?),
      selectedDays: weekdays.isEmpty ? null : weekdays,
      monthlyDay: monthlyDay,
      notificationType: notifType,
    );
  }

  static Map<String, dynamic> _readHiddenMeta(dynamic notes) {
    if (notes is String && notes.isNotEmpty) {
      try {
        final decoded = jsonDecode(notes);
        if (decoded is Map && decoded[_hiddenNotesKey] is Map) {
          return Map<String, dynamic>.from(decoded[_hiddenNotesKey] as Map);
        }
      } catch (_) {}
    }
    return const {};
  }

  static String _freqToString(MedicationFrequency f) {
    switch (f) {
      case MedicationFrequency.daily:
        return 'daily';
      case MedicationFrequency.daysPerWeek:
        return 'weekly';
      case MedicationFrequency.once:
        return 'once';
    }
  }

  static MedicationFrequency _freqFromString(String? s) {
    switch (s) {
      case 'daily':
        return MedicationFrequency.daily;
      case 'weekly':
        return MedicationFrequency.daysPerWeek;
      case 'once':
        return MedicationFrequency.once;
      default:
        return MedicationFrequency.daily;
    }
  }

  /// Weekday.monday (index 2 in the local enum) → ISO 1 (Monday).
  static int _weekdayToIso(Weekday w) {
    switch (w) {
      case Weekday.monday:    return 1;
      case Weekday.tuesday:   return 2;
      case Weekday.wednesday: return 3;
      case Weekday.thursday:  return 4;
      case Weekday.friday:    return 5;
      case Weekday.saturday:  return 6;
      case Weekday.sunday:    return 7;
    }
  }

  static Weekday _isoToWeekday(int d) {
    switch (d) {
      case 1: return Weekday.monday;
      case 2: return Weekday.tuesday;
      case 3: return Weekday.wednesday;
      case 4: return Weekday.thursday;
      case 5: return Weekday.friday;
      case 6: return Weekday.saturday;
      case 7: return Weekday.sunday;
      default: return Weekday.monday;
    }
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 8, minute: 0);
    final h = int.tryParse(parts[0]) ?? 8;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static NotificationType? _parseNotifType(String? s) {
    if (s == null) return null;
    for (final t in NotificationType.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}
