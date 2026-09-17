class UserModel {
  final String? id;
  final String name;
  final String email;
  final String role; // 'admin' | 'user'
  final String accessMode; // 'view_only' | 'can_edit'
  final List<String> allowedSections;
  final String? storeOwnerId;
  final String shiftType; // 'all_day' | 'morning' | 'evening' | 'custom'
  final String? shiftStartTime; // e.g. '06:00'
  final String? shiftEndTime; // e.g. '16:00'

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.role = 'admin',
    this.accessMode = 'view_only',
    this.allowedSections = const [
      'dashboard',
      'pantry',
      'expenses',
      'reports',
      'shopping_list',
    ],
    this.storeOwnerId,
    this.shiftType = 'all_day',
    this.shiftStartTime,
    this.shiftEndTime,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get canEdit => isAdmin || accessMode == 'can_edit';

  bool get isReadOnly => !canEdit;

  bool get isShiftRestricted => !isAdmin && shiftType != 'all_day';

  String get effectiveShiftStartTime {
    if (shiftStartTime != null && shiftStartTime!.isNotEmpty) return shiftStartTime!;
    return shiftType == 'morning' ? '06:00' : '16:00';
  }

  String get effectiveShiftEndTime {
    if (shiftEndTime != null && shiftEndTime!.isNotEmpty) return shiftEndTime!;
    return shiftType == 'morning' ? '16:00' : '23:59';
  }

  String get shiftDisplayLabel {
    if (isAdmin || shiftType == 'all_day') {
      return '24 Hours (Anytime)';
    }
    final s = formatTimeDisplay(effectiveShiftStartTime);
    final e = formatTimeDisplay(effectiveShiftEndTime);
    if (shiftType == 'morning') {
      return '☀️ Morning ($s - $e)';
    } else if (shiftType == 'evening') {
      return '🌙 Evening ($s - $e)';
    } else {
      return '⏰ Custom ($s - $e)';
    }
  }

  static String formatTimeDisplay(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final displayM = m.toString().padLeft(2, '0');
      return '$displayH:$displayM $period';
    } catch (_) {
      return hhmm;
    }
  }

  bool isWithinAllowedShift([DateTime? testNow]) {
    if (isAdmin) return true;
    if (shiftType == 'all_day') return true;

    final now = testNow ?? DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startParts = effectiveShiftStartTime.split(':');
    final endParts = effectiveShiftEndTime.split(':');

    final startH = int.tryParse(startParts[0]) ?? 0;
    final startM = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
    final startMinutes = startH * 60 + startM;

    final endH = int.tryParse(endParts[0]) ?? 23;
    final endM = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 59) : 59;
    final endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight window (e.g. 20:00 to 04:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  bool hasAccess(String sectionKey) {
    if (isAdmin) return true;
    return allowedSections.contains(sectionKey);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final sections = json['allowedSections'];
    List<String> list = [];
    if (sections is List) {
      list = sections.map((e) => e.toString()).toList();
    } else {
      list = const [
        'dashboard',
        'pantry',
        'expenses',
        'reports',
        'shopping_list',
      ];
    }

    final role = (json['role'] as String?) ?? 'admin';
    final rawAccessMode = json['accessMode'] as String?;
    final accessMode = rawAccessMode ?? (role == 'admin' ? 'can_edit' : 'view_only');
    final storeOwnerId = (json['storeOwnerId'] ?? json['createdBy'])?.toString();
    final shiftType = (json['shiftType'] as String?) ?? 'all_day';
    final shiftStartTime = json['shiftStartTime'] as String?;
    final shiftEndTime = json['shiftEndTime'] as String?;

    return UserModel(
      id: (json['_id'] ?? json['id']) as String?,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: role,
      accessMode: accessMode,
      allowedSections: list,
      storeOwnerId: storeOwnerId,
      shiftType: shiftType,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        '_id': id,
        'name': name,
        'email': email,
        'role': role,
        'accessMode': accessMode,
        'allowedSections': allowedSections,
        if (storeOwnerId != null) 'storeOwnerId': storeOwnerId,
        'shiftType': shiftType,
        if (shiftStartTime != null) 'shiftStartTime': shiftStartTime,
        if (shiftEndTime != null) 'shiftEndTime': shiftEndTime,
      };
}
