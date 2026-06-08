enum FastingPlan {
  h12,
  h14,
  h16,
  h18,
  h20,
  custom,
}

extension FastingPlanExtension on FastingPlan {
  String get nameString {
    switch (this) {
      case FastingPlan.h12:
        return '12:12';
      case FastingPlan.h14:
        return '14:10';
      case FastingPlan.h16:
        return '16:8';
      case FastingPlan.h18:
        return '18:6';
      case FastingPlan.h20:
        return '20:4';
      case FastingPlan.custom:
        return 'Custom';
    }
  }

  int get targetSeconds {
    switch (this) {
      case FastingPlan.h12:
        return 12 * 3600;
      case FastingPlan.h14:
        return 14 * 3600;
      case FastingPlan.h16:
        return 16 * 3600;
      case FastingPlan.h18:
        return 18 * 3600;
      case FastingPlan.h20:
        return 20 * 3600;
      case FastingPlan.custom:
        return 0;
    }
  }

  String get description {
    switch (this) {
      case FastingPlan.h12:
        return 'Simple fasting for beginners';
      case FastingPlan.h14:
        return 'Gentle fast for daily balance';
      case FastingPlan.h16:
        return 'Popular lean gains method';
      case FastingPlan.h18:
        return 'Advanced fat-loss window';
      case FastingPlan.h20:
        return 'Warrior diet fast';
      case FastingPlan.custom:
        return 'Set your own target hours';
    }
  }
}
