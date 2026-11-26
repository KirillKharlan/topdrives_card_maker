/// What a field of [CarPhysics] holds: a number (plain text field), a yes/no value or one of a
/// few choices (both picked from a list). The kind also decides how the stored text is turned
/// into json.
enum PhysicsKind { number, flag, choice }

class PhysicsField {
  const PhysicsField(
    this.key,
    this.label, {
    this.kind = PhysicsKind.number,
    this.help = '',
    this.options = const [],
  });

  /// The name used in the game's files and in the exported json.
  final String key;
  final String label;
  final PhysicsKind kind;
  final String help;

  /// The list to pick from ([PhysicsKind.choice] only).
  final List<String> options;
}

/// The hidden numbers the game uses to simulate a race, typed in by hand. They are
/// independent of the numbers shown on the card (the mass here is not the weight of the
/// card). Everything is kept as text, so an empty field stays empty.
class CarPhysics {
  CarPhysics([Map<String, String>? values]) : values = values ?? <String, String>{};

  factory CarPhysics.fromJson(Map<String, dynamic>? json) {
    final out = CarPhysics();
    if (json == null) return out;
    for (final f in fields) {
      final v = json[f.key];
      if (v is String && v.isNotEmpty) out.values[f.key] = v;
    }
    return out;
  }

  /// Tyre types of the beta game (TopDrives_Beta_Tyre_Data.csv).
  static const tyreTypes = [
    'Drag',
    'Formula',
    'HiPerformance',
    'Offroad',
    'Slicks',
    'StockCar',
    'Tourism',
    'Truck',
  ];

  static const groundClearances = ['Low', 'Medium', 'High'];

  /// Picked from a list: ground clearance, traction control, ABS, tyre type. The rest is typed.
  static const fields = <PhysicsField>[
    PhysicsField('m_horsepower', 'Engine power', help: 'm_horsepower'),
    PhysicsField('m_torque', 'Torque', help: 'm_torque'),
    PhysicsField('m_mass', 'Vehicle mass', help: 'm_mass'),
    PhysicsField('m_Cd', 'Drag coefficient (Cd)', help: 'm_Cd'),
    PhysicsField('m_dragMultiplier', 'Extra drag multiplier', help: 'm_dragMultiplier'),
    PhysicsField('m_accelPoint1Time', 'Accel point 1: time', help: 'm_accelPoint1Time'),
    PhysicsField('m_accelPoint1Speed', 'Accel point 1: speed', help: 'm_accelPoint1Speed'),
    PhysicsField('m_accelPoint2Time', 'Accel point 2: time', help: 'm_accelPoint2Time'),
    PhysicsField('m_accelPoint2Speed', 'Accel point 2: speed', help: 'm_accelPoint2Speed'),
    PhysicsField('m_timeToTopSpeed', 'Time to top speed', help: 'm_timeToTopSpeed'),
    PhysicsField('m_brakingDecelerationRate', 'Braking deceleration rate',
        help: 'm_brakingDecelerationRate'),
    PhysicsField('m_handling', 'Handling', help: 'm_handling'),
    PhysicsField('m_agility', 'Agility', help: 'm_agility'),
    PhysicsField('m_hillAbility', 'Hill ability', help: 'm_hillAbility'),
    PhysicsField('m_groundClearance', 'Ground clearance',
        kind: PhysicsKind.choice, help: 'm_groundClearance', options: groundClearances),
    PhysicsField('m_tractionControl', 'Traction control',
        kind: PhysicsKind.flag, help: 'm_tractionControl'),
    PhysicsField('m_ABS', 'ABS', kind: PhysicsKind.flag, help: 'm_ABS'),
    PhysicsField('tyreType', 'Tyre type',
        kind: PhysicsKind.choice, help: 'tyreType', options: tyreTypes),
  ];

  /// key -> stored text; a field that is empty is not in the map.
  final Map<String, String> values;

  String operator [](String key) => values[key] ?? '';

  void set(String key, String value) {
    final text = value.trim();
    if (text.isEmpty) {
      values.remove(key);
    } else {
      values[key] = text;
    }
  }

  bool get isEmpty => values.isEmpty;

  bool get isNotEmpty => values.isNotEmpty;

  /// How many fields are filled in.
  int get filled => values.length;

  static num? _number(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v == v.roundToDouble() && v.abs() < 1e15 ? v.toInt() : v;
  }

  static const _yes = {'true', 'yes', 'y', '1', 'on'};
  static const _no = {'false', 'no', 'n', '0', 'off'};

  /// A stored yes/no text as 'true', 'false' or '' (not set, or something else).
  static String flagValue(String raw) {
    final low = raw.trim().toLowerCase();
    if (_yes.contains(low)) return 'true';
    if (_no.contains(low)) return 'false';
    return '';
  }

  /// The stored text of a field with the type it looks like: a number field gives a number,
  /// a yes/no field gives true / false, a choice stays text. Whatever does not fit stays as the
  /// text that was typed (nothing is thrown away); an empty field is null.
  static dynamic typed(PhysicsField f, String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    switch (f.kind) {
      case PhysicsKind.number:
        return _number(text) ?? text;
      case PhysicsKind.flag:
        final flag = flagValue(text);
        return flag.isEmpty ? text : flag == 'true';
      case PhysicsKind.choice:
        return text;
    }
  }

  /// Every field with its type guessed from what was stored (see [typed]).
  Map<String, dynamic> toExport() => {
        for (final f in fields) f.key: typed(f, this[f.key]),
      };

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}
