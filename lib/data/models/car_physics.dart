/// How a field of [CarPhysics] is typed in: a number, a yes/no choice, or a tyre type from the list.
enum PhysicsKind { number, flag, tyre }

class PhysicsField {
  const PhysicsField(this.key, this.label, {this.kind = PhysicsKind.number, this.help = ''});

  /// The name used in the game's files and in the exported json.
  final String key;
  final String label;
  final PhysicsKind kind;
  final String help;
}

/// The hidden numbers the game uses to simulate a race, typed in by hand. They are
/// independent of the numbers shown on the card (the mass here is not the weight of the
/// card). Everything is kept as the text that was typed, so an empty field stays empty.
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
    PhysicsField('m_groundClearance', 'Ground clearance', help: 'm_groundClearance'),
    PhysicsField('m_tractionControl', 'Traction control',
        kind: PhysicsKind.flag, help: 'm_tractionControl'),
    PhysicsField('m_ABS', 'ABS', kind: PhysicsKind.flag, help: 'm_ABS'),
    PhysicsField('tyreType', 'Tyre type', kind: PhysicsKind.tyre, help: 'tyreType'),
  ];

  /// key -> typed text; a field that is empty is not in the map.
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

  /// Every field with its real type: numbers as numbers, yes/no as true/false, the tyre
  /// type as text. A field that is empty (or a number field that is not a number) is null.
  Map<String, dynamic> toExport() {
    final out = <String, dynamic>{};
    for (final f in fields) {
      final text = this[f.key];
      switch (f.kind) {
        case PhysicsKind.number:
          out[f.key] = text.isEmpty ? null : _number(text);
        case PhysicsKind.flag:
          out[f.key] = text == 'true' ? true : (text == 'false' ? false : null);
        case PhysicsKind.tyre:
          out[f.key] = text.isEmpty ? null : text;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}
