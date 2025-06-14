﻿import 'package:duri_care/models/iot_device_model.dart';
import 'package:duri_care/models/irrigation_history_model.dart';
import 'package:duri_care/models/zone_model.dart';
import 'package:duri_care/models/zone_schedule.dart';
import 'package:duri_care/core/services/connectivity_service.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ZoneService extends GetxService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();
  static ZoneService get to => Get.find<ZoneService>();

  Future<ZoneService> init() async {
    return this;
  }

  Future<List<ZoneModel>?> loadZones(String userId) async {
    return await _connectivity.executeWithConnectivity(() async {
      final response = await _supabase
          .from('zones')
          .select('*, zone_users!inner(*)')
          .eq('zone_users.user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true);

      return response.map<ZoneModel>((data) {
        final zone = ZoneModel.fromMap(data);
        return zone;
      }).toList();
    });
  }

  Future<List<ZoneModel>?> loadAllZones() async {
    return await _connectivity.executeWithConnectivity(() async {
      final response = await _supabase
          .from('zones')
          .select('*')
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true);

      return response.map<ZoneModel>((data) {
        final zone = ZoneModel.fromMap(data);
        return zone;
      }).toList();
    });
  }

  Future<ZoneModel?> loadZoneById(int zoneId, String userId) async {
    return await _connectivity.executeWithConnectivity(() async {
      final response =
          await _supabase
              .from('zones')
              .select('*, zone_users!inner(*)')
              .eq('id', zoneId)
              .eq('zone_users.user_id', userId)
              .filter('deleted_at', 'is', null)
              .single();
      return ZoneModel.fromMap(response);
    });
  }

  Future<List<IotDeviceModel>?> loadDevicesForZone(int zoneId) async {
    return await _connectivity.executeWithConnectivity(() async {
      final response = await _supabase
          .from('iot_devices')
          .select()
          .eq('zone_id', zoneId);

      return response
          .map<IotDeviceModel>((data) => IotDeviceModel.fromMap(data))
          .toList();
    });
  }

  Future<List<IotDeviceModel>?> loadAllDevices() async {
    return await _connectivity.executeWithConnectivity(() async {
      final response = await _supabase
          .from('iot_devices')
          .select('*, zone:zones(*)')
          .order('id', ascending: true);

      return response.map<IotDeviceModel>((data) {
        final Map<String, dynamic> deviceData = {
          'id': data['id'],
          'zone_id': data['zone_id'],
          'iot_code': data['code'] ?? 0,
          'name': data['name'] ?? 'Unknown Device',
        };
        return IotDeviceModel.fromMap(deviceData);
      }).toList();
    });
  }

  Future<IrrigationHistoryModel?> loadIrrigationHistory(int zoneId) async {
    return await _connectivity.executeWithConnectivity(() async {
      final response =
          await _supabase
              .from('irrigation_histories')
              .select()
              .eq('zone_id', zoneId)
              .order('created_at', ascending: false)
              .limit(1)
              .single();

      return IrrigationHistoryModel.fromMap(response);
    });
  }

  Future<List<IrrigationHistoryModel>?> loadAllIrrigationHistory(
    int zoneId,
  ) async {
    return await _connectivity.executeWithConnectivity(() async {
      final response = await _supabase
          .from('irrigation_histories')
          .select()
          .eq('zone_id', zoneId)
          .order('created_at', ascending: false);

      return response
          .map<IrrigationHistoryModel>(
            (data) => IrrigationHistoryModel.fromMap(data),
          )
          .toList();
    });
  }

  Future<ZoneModel?> createZone({
    required String name,
    required int zoneCode,
    required String userId,
  }) async {
    return await _connectivity.executeWithConnectivity(() async {
      final existing =
          await _supabase
              .from('zones')
              .select('id')
              .eq('name', name)
              .filter('deleted_at', 'is', null)
              .maybeSingle();

      if (existing != null) {
        throw Exception('Zona dengan nama "$name" sudah ada');
      }

      final existingActiveCode =
          await _supabase
              .from('zones')
              .select('id, name')
              .eq('zone_code', zoneCode)
              .filter('deleted_at', 'is', null)
              .maybeSingle();

      if (existingActiveCode != null) {
        throw Exception(
          'Kode zona $zoneCode sudah digunakan oleh zona "${existingActiveCode['name']}"',
        );
      }
      final existingDeletedCode =
          await _supabase
              .from('zones')
              .select('id')
              .eq('zone_code', zoneCode)
              .not('deleted_at', 'is', null)
              .maybeSingle();

      if (existingDeletedCode != null) {
        await _supabase
            .from('zones')
            .update({'zone_code': null})
            .eq('id', existingDeletedCode['id']);
      }

      final newZone =
          await _supabase
              .from('zones')
              .insert({
                'name': name,
                'is_active': false,
                'zone_code': zoneCode,
                'manual_duration': 5,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      final zoneId = newZone['id']?.toString();
      if (zoneId == null) {
        throw Exception('Failed to get zone ID after creation');
      }

      await _supabase.from('zone_users').insert({
        'zone_id': zoneId,
        'user_id': userId,
        'allow_auto_schedule': true,
      });

      return ZoneModel.fromMap(newZone);
    });
  }

  Future<void> deleteZone(int zoneId) async {
    await _connectivity.executeWithConnectivity(() async {
      await _supabase
          .from('zones')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'zone_code': null,
          })
          .eq('id', zoneId);
    });
  }

  Future<ZoneModel?> updateZone({
    required String zoneId,
    required String newName,
    required int zoneCode,
  }) async {
    return await _connectivity.executeWithConnectivity(() async {
      final existing =
          await _supabase
              .from('zones')
              .select('id')
              .eq('name', newName.trim())
              .neq('id', zoneId)
              .filter('deleted_at', 'is', null)
              .maybeSingle();

      if (existing != null) {
        throw Exception('Zona dengan nama "$newName" sudah ada');
      }

      final existingCode =
          await _supabase
              .from('zones')
              .select('id, name')
              .eq('zone_code', zoneCode)
              .neq('id', zoneId)
              .filter('deleted_at', 'is', null)
              .maybeSingle();

      if (existingCode != null) {
        throw Exception(
          'Kode zona $zoneCode sudah digunakan oleh zona "${existingCode['name']}"',
        );
      }

      final updated =
          await _supabase
              .from('zones')
              .update({'name': newName.trim(), 'zone_code': zoneCode})
              .eq('id', zoneId)
              .select()
              .single();

      return ZoneModel.fromMap(updated);
    });
  }

  Future<ZoneModel?> saveDuration(int zoneId, int duration) async {
    return await _connectivity.executeWithConnectivity(() async {
      final updatedZone =
          await _supabase
              .from('zones')
              .update({'manual_duration': duration})
              .eq('id', zoneId)
              .select()
              .single();
      return ZoneModel.fromMap(updatedZone);
    });
  }

  Future<ZoneModel?> toggleZoneActive(dynamic zoneId) async {
    return await _connectivity.executeWithConnectivity(() async {
      final zone =
          await _supabase
              .from('zones')
              .select('id, is_active, manual_duration, name')
              .eq('id', zoneId)
              .single();

      final currentState = zone['is_active'];
      final newState = !currentState;

      final updatedZone =
          await _supabase
              .from('zones')
              .update({'is_active': newState})
              .eq('id', zoneId)
              .select()
              .single();

      final userId = _supabase.auth.currentUser?.id;

      String fullname = 'User';
      if (userId != null) {
        try {
          final userResponse =
              await _supabase
                  .from('users')
                  .select('fullname')
                  .eq('id', userId)
                  .single();
          fullname = userResponse['fullname'];
        } catch (e) {
          fullname = 'Unknown User';
        }
      }

      if (newState) {
        final message =
            '$fullname memulai penyiraman manual dengan durasi ${zone['manual_duration']} menit';

        await _supabase.from('irrigation_histories').insert({
          'zone_id': zoneId,
          'executed_by': userId,
          'started_at': DateTime.now().toIso8601String(),
          'duration': zone['manual_duration'],
          'type': 'manual',
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return ZoneModel.fromMap(updatedZone);
    });
  }

  Future<Map<String, dynamic>?> createSchedule({
    required DateTime scheduledDateTime,
    required int duration,
    required String zoneId,
  }) async {
    return await _connectivity.executeWithConnectivity(() async {
      try {
        Map<String, dynamic> scheduleData;
        dynamic scheduleId;

        try {
          final insertedSchedule =
              await _supabase
                  .from('irrigation_schedules')
                  .insert({
                    'duration': duration,
                    'status_id': 1,
                    'scheduled_at': scheduledDateTime.toIso8601String(),
                    'executed': false,
                  })
                  .select()
                  .single();
          scheduleId = insertedSchedule['id'];
          scheduleData = insertedSchedule;
        } catch (e) {
          final existingSchedule =
              await _supabase
                  .from('irrigation_schedules')
                  .select()
                  .eq('scheduled_at', scheduledDateTime.toIso8601String())
                  .eq('duration', duration)
                  .maybeSingle();

          if (existingSchedule != null) {
            scheduleId = existingSchedule['id'];
            scheduleData = existingSchedule;
          } else {
            throw Exception('Failed to create or find schedule: $e');
          }
        }

        final existingZoneSchedule =
            await _supabase
                .from('zone_schedules')
                .select()
                .eq('zone_id', int.parse(zoneId))
                .eq('schedule_id', scheduleId)
                .maybeSingle();

        if (existingZoneSchedule == null) {
          await _supabase.from('zone_schedules').insert({
            'zone_id': int.parse(zoneId),
            'schedule_id': scheduleId,
          });
        }

        return scheduleData;
      } catch (e) {
        throw Exception('Gagal membuat jadwal: $e');
      }
    });
  }

  Future<Map<String, dynamic>?> deleteSchedule(
    int scheduleId,
    int zoneId,
  ) async {
    return await _connectivity.executeWithConnectivity(() async {
      try {
        await _supabase
            .from('zone_schedules')
            .delete()
            .eq('zone_id', zoneId)
            .eq('schedule_id', scheduleId)
            .select();
        final otherUsages = await _supabase
            .from('zone_schedules')
            .select('zone_id')
            .eq('schedule_id', scheduleId);

        if (otherUsages.isEmpty) {
          await _supabase
              .from('irrigation_schedules')
              .delete()
              .eq('id', scheduleId)
              .select();
          return {
            'success': true,
            'message': 'Jadwal berhasil dihapus sepenuhnya',
            'wasCompletelyDeleted': true,
          };
        }

        return {
          'success': true,
          'message': 'Jadwal berhasil dihapus dari zona ini',
          'wasCompletelyDeleted': false,
          'remainingZones': otherUsages.length,
        };
      } on PostgrestException catch (e) {
        throw Exception('Gagal menghapus jadwal: ${e.message}');
      } catch (e) {
        throw Exception('Terjadi kesalahan: $e');
      }
    });
  }

  Future<List<ZoneScheduleModel>?> loadZoneSchedules(int zoneId) async {
    return await _connectivity.executeWithConnectivity(() async {
      try {
        final data = await _supabase
            .from('zone_schedules')
            .select(
              'zone_id, schedule:schedule_id!inner(id, scheduled_at, duration, executed, status_id)',
            )
            .eq('zone_id', zoneId)
            .eq('schedule.executed', false);

        final scheduleList =
            (data as List)
                .map((item) => ZoneScheduleModel.fromMap(item))
                .toList();

        scheduleList.sort(
          (a, b) => a.schedule.scheduledAt.compareTo(b.schedule.scheduledAt),
        );

        return scheduleList;
      } catch (e) {
        throw Exception('Failed to load zone schedules: $e');
      }
    });
  }

  Future<List<ZoneScheduleModel>?> loadAllZoneSchedules() async {
    return await _connectivity.executeWithConnectivity(() async {
      try {
        final data = await _supabase
            .from('zone_schedules')
            .select(
              'zone_id, schedule:schedule_id!inner(id, scheduled_at, duration, executed, status_id)',
            )
            .eq('schedule.executed', false);

        final scheduleList =
            (data as List)
                .map((item) => ZoneScheduleModel.fromMap(item))
                .toList();

        scheduleList.sort(
          (a, b) => a.schedule.scheduledAt.compareTo(b.schedule.scheduledAt),
        );

        return scheduleList;
      } catch (e) {
        throw Exception('Failed to load all zone schedules: $e');
      }
    });
  }

  Stream<List<Map<String, dynamic>>> zoneChangesStream() {
    return _supabase
        .from('zones')
        .stream(primaryKey: ['id'])
        .map((event) => event);
  }
}
