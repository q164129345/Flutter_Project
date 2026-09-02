class MotorControlCommand {
  const MotorControlCommand({
    required this.enabled,
    required this.targetSpeedRpm,
  });

  final bool enabled;
  final int targetSpeedRpm;
}

/// PID values represented in the engineering units used by the UI.
class PidParameters {
  const PidParameters({
    required this.kp,
    required this.ki,
    required this.kd,
    required this.ramp,
    required this.tf,
  });

  final double kp;
  final double ki;
  final double kd;
  final double ramp;
  final double tf;

  @override
  String toString() {
    return 'PidParameters(kp: $kp, ki: $ki, kd: $kd, ramp: $ramp, tf: $tf)';
  }
}

class CurrentLoopParameters {
  const CurrentLoopParameters({required this.iq, required this.id});

  final PidParameters iq;
  final PidParameters id;
}

class MotorLimits {
  const MotorLimits({required this.voltageLimit, required this.currentLimit});

  final double voltageLimit;
  final double currentLimit;
}
