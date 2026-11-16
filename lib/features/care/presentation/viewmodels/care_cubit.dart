import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/care_notification_service.dart';
import '../../data/patient_progress_api.dart';
import '../../data/patient_diet_api.dart';
import '../../domain/models/care_models.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../../../treatment/data/patient_clinical_api.dart';
import '../../../shop/data/datasources/commerce_remote_data_source.dart';
import 'care_state.dart';

class CareCubit extends Cubit<CareState> {
  static const _routineHistoryKey = 'care_routine_completion_days_v1';
  static const _careDataClearedKey = 'care_personal_data_cleared_v1';
  CareNotificationService? _notificationService;
  final PatientClinicalApi _clinicalApi;
  final PatientProgressApi _progressApi;
  final CommerceRemoteDataSource _commerceDataSource;
  final PatientDietApi _dietApi;
  String? _patientId;
  String? _sessionToken;

  String get _checkInsKey => _patientId != null && _patientId!.isNotEmpty
      ? 'care_checkins_${_patientId}_v1'
      : 'care_checkins_v1';

  String get _ordersKey => _patientId != null && _patientId!.isNotEmpty
      ? 'care_orders_${_patientId}_v1'
      : 'care_orders_v1';

  String get _routineTasksKey => _patientId != null && _patientId!.isNotEmpty
      ? 'care_routine_tasks_${_patientId}_v1'
      : 'care_routine_tasks_v1';

  String get _careEventsCacheKey => _patientId != null && _patientId!.isNotEmpty
      ? 'care_daily_events_${_patientId}_v1'
      : 'care_daily_events_v1';

  String get _careEventsOutboxKey =>
      _patientId != null && _patientId!.isNotEmpty
      ? 'care_daily_events_outbox_${_patientId}_v1'
      : 'care_daily_events_outbox_v1';

  String get _assistantDietPlanKey =>
      _patientId != null && _patientId!.isNotEmpty
      ? 'care_assistant_diet_plan_${_patientId}_v1'
      : 'care_assistant_diet_plan_v1';

  CareCubit([
    CareNotificationService? notificationService,
    PatientClinicalApi? clinicalApi,
    PatientProgressApi? progressApi,
    CommerceRemoteDataSource? commerceDataSource,
    PatientDietApi? dietApi,
  ]) : _notificationService = notificationService,
       _clinicalApi = clinicalApi ?? PatientClinicalApi(),
       _progressApi = progressApi ?? PatientProgressApi(),
       _commerceDataSource = commerceDataSource ?? CommerceRemoteDataSource(),
       _dietApi = dietApi ?? PatientDietApi(),
       super(const CareState()) {
    _initPersistence();
  }

  Future<void> bindPatient(String? patientId, {String? sessionToken}) async {
    if (patientId == null || patientId.isEmpty) {
      _patientId = null;
      _sessionToken = null;
      if (!isClosed) emit(const CareState());
      return;
    }
    if (_patientId != patientId && !isClosed) {
      emit(const CareState());
    }
    _patientId = patientId;
    _sessionToken = sessionToken;
    await _initPersistence();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      await _syncWithBackend(sessionToken);
    }
  }

  void loadSampleFixturesForTesting() {
    if (isClosed) return;
    _initializeDefaultData();
    emit(state.copyWith(checkIns: ProgressCheckIn.sampleFixtures));
  }

  Future<void> _initPersistence() async {
    final service = _notificationService ??=
        await CareNotificationService.create();
    final status = service.getPermissionStatus();
    final persistedReminders = service.loadReminders();
    final cache = AppLocalCache.instance;
    final cachedTasks = _readList(
      cache.getString(_routineTasksKey),
      RoutineTask.fromJson,
    );
    final persistedTasks = cachedTasks ?? service.loadRoutineTasks();
    final today = _localDayKey(DateTime.now());
    final storedRoutineDay = service.loadRoutineDay();
    final routineTasks = (persistedTasks ?? state.routineTasks)
        .map(
          (task) => storedRoutineDay == today
              ? task
              : task.copyWith(isCompleted: false),
        )
        .toList();
    await service.saveRoutineTasks(routineTasks);
    await service.saveRoutineDay(today);
    final checkIns = _readList(
      cache.getString(_checkInsKey),
      ProgressCheckIn.fromJson,
    );
    final orders = _readList(cache.getString(_ordersKey), CareOrder.fromJson);
    final routineDays = _readList<String>(
      cache.getString(_routineHistoryKey),
      (json) => json['day'] as String? ?? '',
    );
    final careEvents = _readList(
      cache.getString(_careEventsCacheKey),
      CareEvent.fromJson,
    );
    final todayCareEvents = (careEvents ?? state.careEvents)
        .where((event) => event.eventDate == today)
        .toList();
    final assistantDietPlan = _readAssistantDietPlan(
      cache.getString(_assistantDietPlanKey),
    );

    if (isClosed) return;
    await service.syncScheduledReminders(persistedReminders ?? state.reminders);
    emit(
      state.copyWith(
        notificationPermissionStatus: status,
        reminders: persistedReminders ?? state.reminders,
        routineTasks: routineTasks,
        checkIns: checkIns ?? state.checkIns,
        orders: orders ?? state.orders,
        routineCompletionDays: routineDays ?? state.routineCompletionDays,
        assistantDietMeals:
            assistantDietPlan?.meals ?? state.assistantDietMeals,
        assistantDietTitle:
            assistantDietPlan?.title ?? state.assistantDietTitle,
        careEvents: careEvents ?? state.careEvents,
        waterCups: _waterValueForDay(todayCareEvents),
      ),
    );
  }

  Future<void> _syncWithBackend(String token) async {
    try {
      final record = await _clinicalApi.getClinicalRecord(token);
      final syncedCareEvents = await _syncCareEvents(token);
      final currentDay = _localDayKey(DateTime.now());
      final todaysCareEvents = (syncedCareEvents ?? state.careEvents)
          .where((event) => event.eventDate == currentDay)
          .toList();
      final carePlans = record['care_plans'] as List? ?? [];
      List<RoutineTask>? serverTasks;
      if (carePlans.isNotEmpty) {
        final activePlan = carePlans.first;
        if (activePlan is Map) {
          final steps = activePlan['routine_steps'] as List? ?? [];
          serverTasks = _routineTasksFromSteps(
            steps,
            syncedCareEvents ?? state.careEvents,
            currentDay,
          );
        }
      }

      // Also check direct routine-steps endpoint
      try {
        final directSteps = await _clinicalApi.getRoutineSteps(token);
        if (directSteps.isNotEmpty ||
            serverTasks == null ||
            serverTasks.isEmpty) {
          serverTasks = _routineTasksFromSteps(
            directSteps,
            syncedCareEvents ?? state.careEvents,
            currentDay,
          );
        }
      } catch (_) {}

      List<ProgressCheckIn>? serverCheckIns;
      try {
        final rawCheckIns = await _progressApi.listCheckIns(token: token);
        serverCheckIns = rawCheckIns
            .map((item) {
              final photos = (item['photos'] as List? ?? []);
              String? front;
              String? top;
              String? back;
              for (final p in photos) {
                if (p is Map) {
                  final angle = p['angle']?.toString().toLowerCase();
                  final url = p['url']?.toString();
                  if (angle == 'front') front = url;
                  if (angle == 'top') top = url;
                  if (angle == 'back') back = url;
                }
              }
              final primaryPhoto = front ?? top ?? back ?? '';
              final dateStr = item['date']?.toString();
              final date = dateStr != null
                  ? DateTime.tryParse(dateStr) ?? DateTime.now()
                  : DateTime.now();
              return ProgressCheckIn(
                id: item['id']?.toString() ?? '',
                date: date,
                imagePath: primaryPhoto,
                frontImagePath: front,
                topImagePath: top,
                backImagePath: back,
                scalpRegion: item['scalp_region']?.toString() ?? 'Scalp',
                sheddingLevel: item['shedding_level']?.toString() ?? 'Normal',
                notes: item['notes']?.toString() ?? '',
                densityRating: (item['density_rating'] as num?)?.toInt() ?? 3,
                isDoctorReviewed:
                    item['doctor_note'] != null &&
                    item['doctor_note'].toString().trim().isNotEmpty,
                doctorNote: item['doctor_note']?.toString(),
              );
            })
            .where((ci) => ci.id.isNotEmpty)
            .toList();
      } catch (_) {}

      List<CareOrder>? serverOrders;
      try {
        final rawOrders = await _commerceDataSource.fetchPatientOrders(
          token: token,
        );
        serverOrders = rawOrders;
      } catch (_) {}

      List<CareReminder>? serverReminders;
      try {
        final rawReminders = await _clinicalApi.getReminders(token);
        serverReminders = rawReminders
            .map(CareReminder.fromJson)
            .where((r) => r.id.isNotEmpty && r.title.isNotEmpty)
            .toList();
      } catch (_) {}

      if (isClosed) return;
      emit(
        state.copyWith(
          routineTasks:
              serverTasks ??
              (carePlans.isEmpty ? const [] : state.routineTasks),
          careEvents: syncedCareEvents,
          isCareEventSyncPending: state.isCareEventSyncPending,
          waterCups: syncedCareEvents == null
              ? state.waterCups
              : _waterValueForDay(todaysCareEvents),
          routineCompletionDays:
              _routineDaysFromEvents(syncedCareEvents) ??
              state.routineCompletionDays,
          checkIns: serverCheckIns ?? state.checkIns,
          orders: serverOrders ?? state.orders,
          reminders: serverReminders ?? state.reminders,
        ),
      );
      _persistCheckIns();
      if (serverOrders != null) {
        _persistOrders();
      }
      if (serverTasks != null) {
        _persistRoutineTasks();
      }
      if (serverReminders != null) {
        _notificationService?.saveReminders(serverReminders);
      }
      await fetchPatientDietPlan(token);
    } catch (_) {}
  }

  Future<List<CareEvent>?> _syncCareEvents(String token) async {
    final cache = AppLocalCache.instance;
    final pending =
        _readList(cache.getString(_careEventsOutboxKey), CareEvent.fromJson) ??
        <CareEvent>[];
    final remaining = <CareEvent>[];
    for (final event in pending) {
      try {
        await _clinicalApi.saveCareEvent(
          accessToken: token,
          event: event.toJson()..remove('id'),
        );
      } catch (_) {
        remaining.add(event);
      }
    }
    await cache.put(
      _careEventsOutboxKey,
      jsonEncode(remaining.map((event) => event.toJson()).toList()),
    );

    try {
      final today = DateTime.now();
      final remote = await _clinicalApi.getCareEvents(
        accessToken: token,
        from: today.subtract(const Duration(days: 92)),
        to: today,
      );
      final byKey = <String, CareEvent>{
        for (final row in remote)
          _careEventIdentity(CareEvent.fromJson(row)): CareEvent.fromJson(row),
      };
      for (final event in remaining) {
        byKey[_careEventIdentity(event)] = event;
      }
      final events = byKey.values.toList()
        ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
      await cache.put(
        _careEventsCacheKey,
        jsonEncode(events.map((event) => event.toJson()).toList()),
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            careEvents: events,
            isCareEventSyncPending: remaining.isNotEmpty,
          ),
        );
      }
      return events;
    } catch (_) {
      if (!isClosed && remaining.isNotEmpty) {
        emit(state.copyWith(isCareEventSyncPending: true));
      }
      return null;
    }
  }

  String _careEventIdentity(CareEvent event) =>
      '${event.eventDate}|${event.eventType}|${event.eventKey}';

  Future<bool> _recordCareEvent({
    required String eventType,
    required String eventKey,
    required String status,
    int? value,
    String severity = '',
    List<String> symptoms = const [],
    String note = '',
  }) async {
    final event = CareEvent(
      eventDate: _localDayKey(DateTime.now()),
      eventType: eventType,
      eventKey: eventKey,
      status: status,
      value: value,
      severity: severity,
      symptoms: symptoms,
      note: note,
    );
    final identity = _careEventIdentity(event);
    List<CareEvent> replace(List<CareEvent> events, CareEvent item) => [
      item,
      ...events.where((existing) => _careEventIdentity(existing) != identity),
    ];
    final optimistic = replace(state.careEvents, event);
    emit(state.copyWith(careEvents: optimistic));
    final cache = AppLocalCache.instance;
    await cache.put(
      _careEventsCacheKey,
      jsonEncode(optimistic.map((item) => item.toJson()).toList()),
    );

    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      return event.clinicianContactRecommended;
    }

    try {
      final response = await _clinicalApi.saveCareEvent(
        accessToken: token,
        event: event.toJson()..remove('id'),
      );
      final saved = response['item'] is Map
          ? CareEvent.fromJson(
              Map<String, dynamic>.from(response['item'] as Map),
            )
          : event;
      final current = replace(state.careEvents, saved);
      final outbox =
          _readList(
            cache.getString(_careEventsOutboxKey),
            CareEvent.fromJson,
          ) ??
          <CareEvent>[];
      final remaining = outbox
          .where((item) => _careEventIdentity(item) != identity)
          .toList();
      await cache.put(
        _careEventsOutboxKey,
        jsonEncode(remaining.map((item) => item.toJson()).toList()),
      );
      await cache.put(
        _careEventsCacheKey,
        jsonEncode(current.map((item) => item.toJson()).toList()),
      );
      emit(
        state.copyWith(
          careEvents: current,
          isCareEventSyncPending: remaining.isNotEmpty,
        ),
      );
      if (remaining.isNotEmpty) {
        await _syncCareEvents(token);
      }
      return response['clinician_contact_recommended'] == true ||
          saved.clinicianContactRecommended;
    } catch (_) {
      final outbox =
          _readList(
            cache.getString(_careEventsOutboxKey),
            CareEvent.fromJson,
          ) ??
          <CareEvent>[];
      final updatedOutbox = replace(outbox, event);
      await cache.put(
        _careEventsOutboxKey,
        jsonEncode(updatedOutbox.map((item) => item.toJson()).toList()),
      );
      emit(state.copyWith(isCareEventSyncPending: true));
      return event.clinicianContactRecommended;
    }
  }

  List<RoutineTask> _routineTasksFromSteps(
    List<dynamic> steps,
    List<CareEvent> events,
    String day,
  ) => steps
      .asMap()
      .entries
      .map((entry) {
        final value = entry.value;
        if (value is! Map) return null;
        final id = 'rt_${entry.key + 1}';
        final matchingEvents = events.where(
          (item) =>
              item.eventDate == day &&
              item.eventType == 'routine' &&
              item.eventKey == id,
        );
        final event = matchingEvents.isEmpty ? null : matchingEvents.first;
        return RoutineTask(
          id: id,
          title: value['title']?.toString() ?? '',
          subtitle: value['subtitle']?.toString() ?? '',
          category: value['category']?.toString() ?? 'Care',
          timeOfDay: value['time_of_day']?.toString() ?? 'Daily',
          createdBy: value['created_by']?.toString() ?? 'clinician',
          isCompleted: event?.status == 'completed',
          isSkipped: event?.status == 'skipped',
          skipReason: event?.note ?? '',
        );
      })
      .whereType<RoutineTask>()
      .where((task) => task.title.isNotEmpty)
      .toList();

  int? _waterValueForDay(List<CareEvent> events) {
    for (final event in events.reversed) {
      if (event.eventType == 'water' && event.value != null) return event.value;
    }
    return 0;
  }

  List<String>? _routineDaysFromEvents(List<CareEvent>? events) {
    if (events == null) return null;
    return events
        .where(
          (event) =>
              event.eventType == 'routine' &&
              event.eventKey == 'daily_complete' &&
              event.status == 'completed',
        )
        .map((event) => event.eventDate)
        .toSet()
        .toList()
      ..sort();
  }

  String _dietEventKey(DietMeal meal) {
    final raw = '${meal.type}_${meal.name}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'meal_${raw.length > 155 ? raw.substring(0, 155) : raw}';
  }

  Future<void> fetchPatientDietPlan([String? token]) async {
    final activeToken = token ?? _sessionToken;
    if (activeToken == null || activeToken.isEmpty) return;

    if (!isClosed) {
      emit(state.copyWith(isLoadingDiet: true));
    }

    try {
      final res = await _dietApi.getPatientDietPlan(activeToken);
      if (!isClosed) {
        final day = _localDayKey(DateTime.now());
        final todayDietEvents = state.careEvents.where(
          (event) => event.eventDate == day && event.eventType == 'diet',
        );
        final completionByKey = {
          for (final event in todayDietEvents) event.eventKey: event,
        };
        final meals = res.meals.map((meal) {
          final event = completionByKey[_dietEventKey(meal)];
          return meal.copyWith(isCompleted: event?.status == 'completed');
        }).toList();
        final List<List<DietMeal>> plans = meals.isNotEmpty ? [meals] : [];
        emit(
          state.copyWith(
            dietPlans: plans,
            dietTreatmentName: res.treatmentName,
            dietDoctorName: res.doctorName,
            isLoadingDiet: false,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(isLoadingDiet: false));
      }
    }
  }

  Future<bool> saveAssistantDietPlan({
    required String title,
    required List<DietMeal> meals,
  }) async {
    final cleanTitle = title.trim();
    final cleanMeals = meals
        .where((meal) => meal.name.trim().isNotEmpty)
        .take(12)
        .toList(growable: false);
    if (cleanTitle.isEmpty || cleanMeals.isEmpty || isClosed) return false;
    emit(
      state.copyWith(
        assistantDietTitle: cleanTitle,
        assistantDietMeals: cleanMeals,
      ),
    );
    await AppLocalCache.instance.put(
      _assistantDietPlanKey,
      jsonEncode({
        'title': cleanTitle,
        'meals': cleanMeals.map((meal) => meal.toJson()).toList(),
      }),
    );
    return true;
  }

  ({String title, List<DietMeal> meals})? _readAssistantDietPlan(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['meals'];
      if (items is! List) return null;
      final meals = items
          .whereType<Map>()
          .map((item) => DietMeal.fromJson(Map<String, dynamic>.from(item)))
          .where((meal) => meal.name.trim().isNotEmpty)
          .take(12)
          .toList(growable: false);
      final title = decoded['title']?.toString().trim() ?? '';
      if (title.isEmpty || meals.isEmpty) return null;
      return (title: title, meals: meals);
    } catch (_) {
      return null;
    }
  }

  void _initializeDefaultData() {
    if (AppLocalCache.instance.getBool(_careDataClearedKey) == true) return;
    const defaultCheckIns = <ProgressCheckIn>[];

    final defaultTasks = [
      const RoutineTask(
        id: 'rt_1',
        title: 'Dr.Hair 5% Topical Regrowth Booster',
        subtitle: 'Apply 1ml with dropper evenly on crown and hairline',
        category: 'Clinical Topical',
        timeOfDay: 'Evening',
        isCompleted: false,
      ),
      const RoutineTask(
        id: 'rt_2',
        title: 'Biotin & Saw Palmetto Complex',
        subtitle: '1 tablet post-breakfast with water',
        category: 'Oral Supplement',
        timeOfDay: 'Morning',
        isCompleted: false,
      ),
      const RoutineTask(
        id: 'rt_3',
        title: 'Scalp Micro-Circulation Massage',
        subtitle: '4-5 minutes gentle circular fingertips massage',
        category: 'Lifestyle',
        timeOfDay: 'Night',
        isCompleted: false,
      ),
      const RoutineTask(
        id: 'rt_4',
        title: 'Hydration Goal (2.5L Water)',
        subtitle: 'Essential for cellular follicular transport',
        category: 'Lifestyle',
        timeOfDay: 'Throughout Day',
        isCompleted: false,
      ),
    ];

    final defaultReminders = [
      const CareReminder(
        id: 'rem_1',
        title: 'Morning Supplement',
        subtitle: 'Biotin & Saw Palmetto after breakfast',
        time: TimeOfDay(hour: 9, minute: 0),
        isEnabled: true,
        frequency: 'Daily',
      ),
      const CareReminder(
        id: 'rem_2',
        title: 'Evening Topical Booster',
        subtitle: 'Apply 1ml solution before bed',
        time: TimeOfDay(hour: 21, minute: 30),
        isEnabled: true,
        frequency: 'Daily',
      ),
      const CareReminder(
        id: 'rem_3',
        title: 'Weekly Scalp Wash & Exfoliation',
        subtitle: 'Use ketoconazole / clarifying cleanser',
        time: TimeOfDay(hour: 10, minute: 0),
        isEnabled: true,
        frequency: 'Weekly',
      ),
      const CareReminder(
        id: 'rem_4',
        title: 'Monthly Progress Photo Check-in',
        subtitle: 'Take photos under consistent lighting',
        time: TimeOfDay(hour: 11, minute: 0),
        isEnabled: false,
        frequency: 'Monthly',
      ),
    ];

    final defaultDiet = [
      // Day 1: High Protein & Keratin
      [
        const DietMeal(
          type: 'Breakfast',
          name: 'Sprouted Moong & Paneer Omelette / Scramble',
          nutrients: 'Protein (22g) · Biotin · Iron',
          benefit: 'Provides sulfur-rich amino acids required to produce keratin protein chains.',
          isCompleted: true,
        ),
        const DietMeal(
          type: 'Lunch',
          name: 'Palak Dal with Brown Rice & Raw Salad',
          nutrients: 'Folate · Zinc · Plant Iron',
          benefit: 'Enhances red blood cell hemoglobin for optimal oxygen supply to roots.',
          isCompleted: true,
        ),
        const DietMeal(
          type: 'Evening Snack',
          name: 'Roasted Pumpkin & Sunflower Seeds with Walnuts',
          nutrients: 'Omega-3 · Zinc · Magnesium',
          benefit: 'Natural 5-alpha reductase enzyme inhibitor to counter follicular sensitivity.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Dinner',
          name: 'Steamed Greens with Soya Chunks or Grilled Fish',
          nutrients: 'Keratin building blocks · Vitamin E',
          benefit: 'Supports nocturnal follicle matrix cellular regeneration.',
          isCompleted: false,
        ),
      ],
      // Day 2: Zinc & Folate Focus
      [
        const DietMeal(
          type: 'Breakfast',
          name: 'Oats Porridge with Chia Seeds, Almonds & Berries',
          nutrients: 'Silica · Zinc · Antioxidants',
          benefit:
              'Prevents oxidative stress around hair dermal papilla cells.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Lunch',
          name: 'Rajma / Chickpea Curry with Cucumber Raita',
          nutrients: 'Protein (18g) · B-Complex',
          benefit: 'Aids DNA replication and active anagen phase elongation.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Evening Snack',
          name: 'Amla (Indian Gooseberry) Juice with Flax Crackers',
          nutrients: 'Vitamin C · Collagen Co-factor',
          benefit: 'Powers scalp collagen synthesis and increases non-heme iron absorption.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Dinner',
          name: 'Mixed Vegetable Khichdi with Ghee & Curd',
          nutrients: 'Butyric acid · Probiotics',
          benefit: 'Healthy gut microbiome ensures complete micronutrient assimilation.',
          isCompleted: false,
        ),
      ],
      // Day 3: Iron & Follicular Circulation
      [
        const DietMeal(
          type: 'Breakfast',
          name: 'Boiled Eggs / Tofu Stir-Fry with Multigrain Toast',
          nutrients: 'Choline · Vitamin D3 · Protein',
          benefit:
              'Key catalyst for waking dormant telogen follicles into anagen.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Lunch',
          name: 'Methi (Fenugreek) Roti with Black Chana Curry',
          nutrients: 'Nicotinic Acid · Iron · Lecithin',
          benefit: 'Strengthens hair shafts and minimizes breakage.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Evening Snack',
          name: 'Greek Yogurt with Crushed Brazil Nuts',
          nutrients: 'Selenium · Calcium',
          benefit: 'Supports thyroid hormone balance vital for healthy shedding cycle.',
          isCompleted: false,
        ),
        const DietMeal(
          type: 'Dinner',
          name: 'Paneer / Tofu Bhurji with Sauted Bell Peppers',
          nutrients: 'Vitamin A · Carotenoids',
          benefit: 'Normalizes sebum secretion across scalp for healthy follicle breathing.',
          isCompleted: false,
        ),
      ],
    ];

    const defaultOrders = <CareOrder>[];

    emit(
      CareState(
        checkIns: defaultCheckIns,
        routineTasks: defaultTasks,
        reminders: defaultReminders,
        dietPlans: defaultDiet,
        currentDietDay: 0,
        waterCups: 6,
        orders: defaultOrders,
      ),
    );
  }

  // --- PROGRESS CHECK-IN ACTIONS ---
  void addProgressCheckIn({
    String? id,
    required DateTime date,
    required String imagePath,
    String? frontImagePath,
    String? backImagePath,
    String? topImagePath,
    required String scalpRegion,
    required String sheddingLevel,
    required String notes,
    int densityRating = 4,
    String? doctorNote,
  }) {
    final newCheckIn = ProgressCheckIn(
      id: id ?? 'ci_${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      imagePath: imagePath,
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
      topImagePath: topImagePath,
      scalpRegion: scalpRegion,
      sheddingLevel: sheddingLevel,
      notes: notes,
      densityRating: densityRating,
      isDoctorReviewed: false,
      doctorNote:
          doctorNote ??
          'Saved on this device. No clinician has reviewed this check-in.',
    );

    emit(state.copyWith(checkIns: [newCheckIn, ...state.checkIns]));
    _persistCheckIns();
  }

  Future<void> deleteProgressCheckIn(String id, {String? sessionToken}) async {
    if (isClosed) return;
    final token = sessionToken ?? _sessionToken;
    if (token != null && token.isNotEmpty) {
      await _progressApi.deleteCheckIn(token: token, checkInId: id);
    }
    emit(
      state.copyWith(
        checkIns: state.checkIns.where((ci) => ci.id != id).toList(),
      ),
    );
    _persistCheckIns();
  }

  // --- ROUTINE ACTIONS ---
  Future<void> toggleRoutineTask(String id) async {
    final updated = state.routineTasks.map((task) {
      if (task.id == id) {
        return task.copyWith(
          isCompleted: !task.isCompleted,
          isSkipped: false,
          skipReason: '',
        );
      }
      return task;
    }).toList();

    emit(state.copyWith(routineTasks: updated));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(updated);
    _saveRoutineDay();
    _recordRoutineCompletionIfDone(updated);
    final changedTasks = updated.where((item) => item.id == id);
    final task = changedTasks.isEmpty ? null : changedTasks.first;
    if (task != null) {
      await _recordCareEvent(
        eventType: 'routine',
        eventKey: id,
        status: task.isCompleted ? 'completed' : 'pending',
      );
    }
    await _recordCareEvent(
      eventType: 'routine',
      eventKey: 'daily_complete',
      status: updated.isNotEmpty && updated.every((item) => item.isCompleted)
          ? 'completed'
          : 'pending',
    );
  }

  Future<void> skipRoutineTask(String id, {String reason = ''}) async {
    final updated = state.routineTasks
        .map(
          (task) => task.id == id
              ? task.copyWith(
                  isCompleted: false,
                  isSkipped: true,
                  skipReason: reason,
                )
              : task,
        )
        .toList();
    emit(state.copyWith(routineTasks: updated));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(updated);
    _saveRoutineDay();
    _recordRoutineCompletionIfDone(updated);
    await _recordCareEvent(
      eventType: 'routine',
      eventKey: id,
      status: 'skipped',
      note: reason,
    );
    await _recordCareEvent(
      eventType: 'routine',
      eventKey: 'daily_complete',
      status: 'pending',
    );
  }

  Future<bool> addCustomRoutineTask({
    required String title,
    required String subtitle,
    required String category,
    required String timeOfDay,
    String? sessionToken,
  }) async {
    final newTask = RoutineTask(
      id: 'rt_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      category: category,
      timeOfDay: timeOfDay,
      createdBy: 'patient',
      isCompleted: false,
    );

    final updated = [...state.routineTasks, newTask];
    emit(state.copyWith(routineTasks: updated));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(updated);
    _saveRoutineDay();
    _recordRoutineCompletionIfDone(updated);

    final token = sessionToken ?? _sessionToken;
    if (token != null && token.isNotEmpty) {
      try {
        final serverSteps = await _clinicalApi.addRoutineStep(
          accessToken: token,
          title: title,
          subtitle: subtitle,
          category: category,
          timeOfDay: timeOfDay,
        );
        if (serverSteps.isNotEmpty && !isClosed) {
          final completionMap = {
            for (final t in state.routineTasks) t.title: t.isCompleted,
          };
          final refreshed = serverSteps
              .asMap()
              .entries
              .map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final tTitle = s['title']?.toString() ?? '';
                return RoutineTask(
                  id: 'rt_${idx + 1}',
                  title: tTitle,
                  subtitle: s['subtitle']?.toString() ?? '',
                  category: s['category']?.toString() ?? 'Lifestyle',
                  timeOfDay: s['time_of_day']?.toString() ?? 'Daily',
                  createdBy: s['created_by']?.toString() ?? 'clinician',
                  isCompleted: completionMap[tTitle] ?? false,
                );
              })
              .where((t) => t.title.isNotEmpty)
              .toList();

          emit(state.copyWith(routineTasks: refreshed));
          _persistRoutineTasks();
          _notificationService?.saveRoutineTasks(refreshed);
        }
      } catch (_) {
        // Optimistic local update is already saved
      }
    }
    return true;
  }

  Future<bool> removeRoutineTask(
    RoutineTask task, {
    String? sessionToken,
  }) async {
    final index = state.routineTasks.indexOf(task);
    if (index < 0) return false;

    final updated = List<RoutineTask>.from(state.routineTasks)..removeAt(index);
    emit(state.copyWith(routineTasks: updated));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(updated);
    _saveRoutineDay();

    final token = sessionToken ?? _sessionToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _clinicalApi.deleteRoutineStep(
          accessToken: token,
          stepIndex: index,
        );
      } catch (_) {}
    }
    return true;
  }

  Future<void> resetTodayRoutine() async {
    final reset = state.routineTasks
        .map((task) => task.copyWith(isCompleted: false))
        .toList();
    emit(state.copyWith(routineTasks: reset));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(reset);
    _saveRoutineDay();
    _recordRoutineCompletionIfDone(reset);
    for (final task in reset) {
      await _recordCareEvent(
        eventType: 'routine',
        eventKey: task.id,
        status: 'pending',
      );
    }
    await _recordCareEvent(
      eventType: 'routine',
      eventKey: 'daily_complete',
      status: 'pending',
    );
  }

  String _localDayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _saveRoutineDay() {
    _notificationService?.saveRoutineDay(_localDayKey(DateTime.now()));
  }

  void _recordRoutineCompletionIfDone(List<RoutineTask> tasks) {
    final day = _localDayKey(DateTime.now());
    final updatedDays = Set<String>.from(state.routineCompletionDays);
    if (tasks.isNotEmpty && tasks.every((task) => task.isCompleted)) {
      updatedDays.add(day);
    } else {
      updatedDays.remove(day);
    }
    final days = updatedDays.toList()..sort();
    emit(state.copyWith(routineCompletionDays: days));
    AppLocalCache.instance.put(
      _routineHistoryKey,
      jsonEncode(days.map((entry) => {'day': entry}).toList()),
    );
  }

  // --- REMINDER ACTIONS ---
  Future<void> requestNotificationPermission() async {
    final service = _notificationService ??=
        await CareNotificationService.create();
    final status = await service.requestPermission();
    emit(state.copyWith(notificationPermissionStatus: status));
    if (status == NotificationPermissionStatus.granted) {
      await service.syncScheduledReminders(state.reminders);
    }
  }

  Future<bool> saveReminder(
    CareReminder reminder, {
    String? sessionToken,
  }) async {
    final notificationService = _notificationService ??=
        await CareNotificationService.create();
    final token = sessionToken ?? _sessionToken;
    if (token != null && token.isNotEmpty) {
      await _clinicalApi.saveReminder(
        accessToken: token,
        reminderData: reminder.toJson(),
      );
    }

    final existingIndex = state.reminders.indexWhere(
      (r) => r.id == reminder.id,
    );
    List<CareReminder> updated;
    if (existingIndex >= 0) {
      updated = List<CareReminder>.from(state.reminders);
      updated[existingIndex] = reminder;
    } else {
      updated = [...state.reminders, reminder];
    }
    emit(state.copyWith(reminders: updated));
    await notificationService.saveReminders(updated);
    if (reminder.isEnabled) {
      await notificationService.scheduleReminder(reminder);
    } else {
      await notificationService.cancelReminder(reminder.id);
    }
    return true;
  }

  Future<bool> deleteReminder(String id, {String? sessionToken}) async {
    final token = sessionToken ?? _sessionToken;
    if (token != null && token.isNotEmpty) {
      final removed = await _clinicalApi.deleteReminder(
        accessToken: token,
        reminderId: id,
      );
      if (!removed) {
        throw StateError('The reminder was not removed from your account.');
      }
    }

    final updated = state.reminders.where((r) => r.id != id).toList();
    emit(state.copyWith(reminders: updated));
    final notificationService = _notificationService ??=
        await CareNotificationService.create();
    await notificationService.saveReminders(updated);
    await notificationService.cancelReminder(id);
    return true;
  }

  Future<bool> toggleReminder(String id, bool isEnabled) async {
    final matches = state.reminders.where((item) => item.id == id);
    if (matches.isEmpty) return false;
    final reminder = matches.first;
    return saveReminder(reminder.copyWith(isEnabled: isEnabled));
  }

  Future<bool> updateReminderTime(String id, TimeOfDay newTime) async {
    final matches = state.reminders.where((item) => item.id == id);
    if (matches.isEmpty) return false;
    final reminder = matches.first;
    return saveReminder(reminder.copyWith(time: newTime));
  }

  Future<bool> snoozeReminder(
    String id, {
    Duration duration = const Duration(minutes: 15),
  }) async {
    final matches = state.reminders.where((item) => item.id == id);
    if (matches.isEmpty) return false;
    final reminder = matches.first;
    final until = DateTime.now().add(duration);
    return saveReminder(reminder.copyWith(snoozedUntil: until));
  }

  Future<bool> toggleReminderCompletion(String id) async {
    final matches = state.reminders.where((item) => item.id == id);
    if (matches.isEmpty) return false;
    final reminder = matches.first;
    return saveReminder(
      reminder.copyWith(isCompleted: !reminder.isCompleted, clearSnooze: true),
    );
  }

  Future<void> addReminder({
    required String title,
    required String subtitle,
    required TimeOfDay time,
    required String frequency,
    String treatmentType = 'Topical Serum',
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String notes = '',
  }) async {
    final newReminder = CareReminder(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      time: time,
      frequency: frequency,
      treatmentType: treatmentType,
      repeatDays: repeatDays,
      notes: notes,
      isEnabled: true,
    );

    await saveReminder(newReminder);
  }

  void saveLocalOrderPreview({
    required String deliveryAddress,
    required List<String> items,
    required int totalAmount,
  }) {
    final now = DateTime.now();
    final preview = CareOrder(
      orderId: 'PREVIEW-${now.millisecondsSinceEpoch}',
      orderDate: '${now.day}/${now.month}/${now.year}',
      estimatedDelivery: 'Not scheduled',
      status: 'Preview only · not submitted',
      currentStep: 0,
      courierName: '',
      trackingNumber: '',
      deliveryAddress: deliveryAddress,
      items: items,
      totalAmount: totalAmount,
    );
    emit(state.copyWith(orders: [preview, ...state.orders]));
    _persistOrders();
  }

  void addOrder(CareOrder order) {
    emit(state.copyWith(orders: [order, ...state.orders]));
    _persistOrders();
  }

  Future<List<CareOrder>> fetchPatientOrders({
    String? sessionToken,
    String? status,
  }) async {
    final token = sessionToken ?? _sessionToken;
    try {
      final serverOrders = await _commerceDataSource.fetchPatientOrders(
        token: token,
        status: status,
      );
      if (status == null || status.isEmpty) {
        emit(state.copyWith(orders: serverOrders));
        _persistOrders();
      }
      return serverOrders;
    } catch (_) {
      return [];
    }
  }

  Future<CareOrderTracking> fetchOrderTracking(
    String orderId, {
    String? sessionToken,
  }) {
    return _commerceDataSource.fetchOrderTracking(
      token: sessionToken ?? _sessionToken,
      orderId: orderId,
    );
  }

  Future<bool> cancelOrder(
    String orderId, {
    String? reason,
    String? sessionToken,
  }) async {
    final token = sessionToken ?? _sessionToken;
    if (token == null || token.isEmpty) return false;
    try {
      final updatedOrder = await _commerceDataSource.cancelOrder(
        token: token,
        orderId: orderId,
        reason: reason,
      );
      if (updatedOrder != null) {
        final updatedList = state.orders.map((o) {
          return o.orderId == orderId ? updatedOrder : o;
        }).toList();
        emit(state.copyWith(orders: updatedList));
        _persistOrders();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _persistOrders() {
    AppLocalCache.instance.put(
      _ordersKey,
      jsonEncode(state.orders.map((item) => item.toJson()).toList()),
    );
  }

  static List<T>? _readList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  void _persistCheckIns() {
    AppLocalCache.instance.put(
      _checkInsKey,
      jsonEncode(state.checkIns.map((item) => item.toJson()).toList()),
    );
  }

  void _persistRoutineTasks() {
    AppLocalCache.instance.put(
      _routineTasksKey,
      jsonEncode(state.routineTasks.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearPersonalCareData() async {
    final service =
        _notificationService ?? await CareNotificationService.create();
    for (final reminder in state.reminders) {
      await service.cancelReminder(reminder.id);
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        checkIns: const [],
        routineTasks: const [],
        reminders: const [],
        dietPlans: const [],
        dietTreatmentName: '',
        dietDoctorName: '',
        waterCups: 0,
        careEvents: const [],
        isCareEventSyncPending: false,
        routineCompletionDays: const [],
        orders: const [],
      ),
    );
    final cache = AppLocalCache.instance;
    for (final key in [
      _checkInsKey,
      'care_checkins_v1',
      _ordersKey,
      'care_orders_v1',
      _routineTasksKey,
      _careEventsCacheKey,
      _careEventsOutboxKey,
      'care_daily_events_v1',
      'care_daily_events_outbox_v1',
      'care_routine_tasks_v1',
      'care_bookings_v1',
      _routineHistoryKey,
      'care_persisted_routine_v1',
      'care_persisted_reminders_v1',
      'care_persisted_routine_day_v1',
      'care_notification_permission_status',
    ]) {
      await cache.remove(key);
    }
    _patientId = null;
    _sessionToken = null;
    await cache.put(_careDataClearedKey, true);
  }

  /// Resets interactive care flows to their original demo fixtures.
  Future<void> resetForDemo() async {
    final service =
        _notificationService ?? await CareNotificationService.create();
    for (final reminder in state.reminders) {
      await service.cancelReminder(reminder.id);
    }

    final cache = AppLocalCache.instance;
    for (final key in [
      _checkInsKey,
      'care_bookings_v1',
      _ordersKey,
      _routineHistoryKey,
      _careDataClearedKey,
      'care_persisted_routine_v1',
      'care_persisted_reminders_v1',
      'care_persisted_routine_day_v1',
      'care_notification_permission_status',
    ]) {
      await cache.remove(key);
    }

    emit(const CareState());
    await _initPersistence();
  }

  // --- DIET & WATER ACTIONS ---
  void selectDietDay(int dayIndex) {
    emit(state.copyWith(currentDietDay: dayIndex));
  }

  Future<void> toggleDietMeal(int dayIndex, int mealIndex) async {
    if (dayIndex >= state.dietPlans.length) return;
    final dayMeals = List<DietMeal>.from(state.dietPlans[dayIndex]);
    if (mealIndex >= dayMeals.length) return;

    dayMeals[mealIndex] = dayMeals[mealIndex].copyWith(
      isCompleted: !dayMeals[mealIndex].isCompleted,
    );

    final updatedPlans = List<List<DietMeal>>.from(state.dietPlans);
    updatedPlans[dayIndex] = dayMeals;

    emit(state.copyWith(dietPlans: updatedPlans));
    final meal = dayMeals[mealIndex];
    await _recordCareEvent(
      eventType: 'diet',
      eventKey: _dietEventKey(meal),
      status: meal.isCompleted ? 'completed' : 'pending',
    );
  }

  Future<void> setWater(int count) async {
    final value = count.clamp(0, 12);
    emit(state.copyWith(waterCups: value));
    await _recordCareEvent(
      eventType: 'water',
      eventKey: 'daily_water',
      status: 'logged',
      value: value,
    );
  }

  Future<void> onNotificationActionTaken() async {
    final updatedTasks = state.routineTasks
        .map((task) => task.copyWith(isCompleted: true))
        .toList();
    emit(state.copyWith(routineTasks: updatedTasks));
    _persistRoutineTasks();
    _notificationService?.saveRoutineTasks(updatedTasks);
    _recordRoutineCompletionIfDone(updatedTasks);
  }

  Future<void> onNotificationActionSnooze() async {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
    await _recordCareEvent(
      eventType: 'routine_snooze',
      eventKey: 'snooze_${DateTime.now().millisecondsSinceEpoch}',
      status: 'snoozed',
      value: snoozeTime.millisecondsSinceEpoch,
    );
  }

  Future<void> incrementWater() async {
    final value = (state.waterCups + 1).clamp(0, 12);
    emit(state.copyWith(waterCups: value));
    await _recordCareEvent(
      eventType: 'water',
      eventKey: 'daily_water',
      status: 'logged',
      value: value,
    );
  }

  Future<void> decrementWater() async {
    final value = (state.waterCups - 1).clamp(0, 12);
    emit(state.copyWith(waterCups: value));
    await _recordCareEvent(
      eventType: 'water',
      eventKey: 'daily_water',
      status: 'logged',
      value: value,
    );
  }

  Future<bool> logSymptoms({
    required List<String> symptoms,
    required String severity,
    String note = '',
  }) async {
    final eventKey = 'symptom_${DateTime.now().millisecondsSinceEpoch}';
    return _recordCareEvent(
      eventType: 'symptom',
      eventKey: eventKey,
      status: 'logged',
      symptoms: symptoms,
      severity: severity,
      note: note,
    );
  }
}
