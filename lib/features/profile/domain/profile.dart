import 'dart:convert';

enum FitnessGoal {
  weightLoss,
  muscleGain,
  maintenance,
  improveHealth;

  String get label => switch (this) {
        FitnessGoal.weightLoss => 'Weight Loss',
        FitnessGoal.muscleGain => 'Muscle Gain',
        FitnessGoal.maintenance => 'Maintenance',
        FitnessGoal.improveHealth => 'Improve Health',
      };

  static FitnessGoal fromLabel(String label) =>
      FitnessGoal.values.firstWhere((g) => g.label == label,
          orElse: () => FitnessGoal.maintenance);
}

enum ActivityLevel {
  sedentary,
  lightlyActive,
  active,
  veryActive;

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.lightlyActive => 'Lightly Active',
        ActivityLevel.active => 'Active',
        ActivityLevel.veryActive => 'Very Active',
      };

  static ActivityLevel fromLabel(String label) =>
      ActivityLevel.values.firstWhere((a) => a.label == label,
          orElse: () => ActivityLevel.lightlyActive);
}

enum BiologicalSex {
  male,
  female;

  String get label => switch (this) {
        BiologicalSex.male => 'Male',
        BiologicalSex.female => 'Female',
      };
}

class Profile {
  final FitnessGoal goal;
  final ActivityLevel activityLevel;
  final int? ageYears;
  final double? weightKg;
  final double? heightCm;
  final BiologicalSex? sex;

  const Profile({
    required this.goal,
    required this.activityLevel,
    this.ageYears,
    this.weightKg,
    this.heightCm,
    this.sex,
  });

  bool get isComplete =>
      ageYears != null && weightKg != null && heightCm != null;

  Profile copyWith({
    FitnessGoal? goal,
    ActivityLevel? activityLevel,
    int? ageYears,
    double? weightKg,
    double? heightCm,
    BiologicalSex? sex,
  }) =>
      Profile(
        goal: goal ?? this.goal,
        activityLevel: activityLevel ?? this.activityLevel,
        ageYears: ageYears ?? this.ageYears,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        sex: sex ?? this.sex,
      );

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'activityLevel': activityLevel.name,
        'ageYears': ageYears,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sex': sex?.name,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        goal: FitnessGoal.values.byName(json['goal'] as String),
        activityLevel:
            ActivityLevel.values.byName(json['activityLevel'] as String),
        ageYears: json['ageYears'] as int?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        sex: json['sex'] == null
            ? null
            : BiologicalSex.values.byName(json['sex'] as String),
      );

  String encode() => jsonEncode(toJson());
  static Profile decode(String raw) =>
      Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
