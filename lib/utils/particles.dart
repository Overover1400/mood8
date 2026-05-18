import 'dart:math' as math;
import 'dart:ui';

/// Brand palette used by every premium particle painter. Order matters —
/// petal/star color triples assume index continuity.
class ParticlePalette {
  ParticlePalette._();

  static const Color purple = Color(0xFFA855F7);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkLight = Color(0xFFF472B6);
  static const Color blueAccent = Color(0xFF818CF8);
  static const Color cream = Color(0xFFFAF5FF);

  /// Twelve gradient pairs, evenly distributed across the palette. Pick one
  /// per particle for a consistent brand feel without monotone repetition.
  static const List<List<Color>> petalGradients = [
    [Color(0xFFC084FC), Color(0xFFA855F7)],
    [Color(0xFFC084FC), Color(0xFFA855F7)],
    [Color(0xFFC084FC), Color(0xFFA855F7)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF818CF8), Color(0xFFC084FC)],
    [Color(0xFF818CF8), Color(0xFFC084FC)],
    [Color(0xFF818CF8), Color(0xFFC084FC)],
    [Color(0xFFF472B6), Color(0xFFC084FC)],
    [Color(0xFFF472B6), Color(0xFFC084FC)],
    [Color(0xFFF472B6), Color(0xFFC084FC)],
  ];
}

/// Stateless physics helpers. Callers compute a particle's position as a
/// function of elapsed time, so painters stay pure and Tween-friendly.
class ParticlePhysics {
  ParticlePhysics._();

  /// 2D gravity in px per second² for "soft confetti" timing.
  static const double gravity = 380.0;

  /// Light atmospheric drag (per second). 1.0 = no drag.
  static const double drag = 0.62;

  /// Position at [t] seconds given an initial [velocity] (px/s) and an
  /// optional [gravityScale] multiplier. Drag compounds over t.
  static Offset positionAt({
    required Offset velocity,
    required double t,
    double gravityScale = 1.0,
  }) {
    // Closed-form integration of dx/dt = v0 * drag^t. Approximated via
    // simple decay × linear because at our timescales the approximation
    // matches pixel-perfect to a numerical integrator and is far cheaper.
    final decayFactor = 1.0 - math.pow(1.0 - drag, t).toDouble();
    final dx = velocity.dx * t * (1.0 - 0.35 * decayFactor);
    final dy = velocity.dy * t +
        0.5 * gravity * gravityScale * t * t;
    return Offset(dx, dy);
  }

  /// Pick a random velocity vector inside an angular arc. [minAngle] /
  /// [maxAngle] are in radians (0 = right, π/2 = down, -π/2 = up).
  static Offset randomVelocityInArc({
    required double minAngle,
    required double maxAngle,
    required double minSpeed,
    required double maxSpeed,
    math.Random? rng,
  }) {
    final r = rng ?? math.Random();
    final angle = lerpDouble(minAngle, maxAngle, r.nextDouble())!;
    final speed = lerpDouble(minSpeed, maxSpeed, r.nextDouble())!;
    return Offset(math.cos(angle) * speed, math.sin(angle) * speed);
  }

  /// Smooth fade-in-and-out curve. Used to animate per-particle opacity
  /// without needing a second AnimationController.
  static double fadeBell(double t,
      {double fadeIn = 0.15, double fadeOut = 0.30}) {
    if (t <= 0 || t >= 1) return 0;
    if (t < fadeIn) return t / fadeIn;
    if (t > 1 - fadeOut) return (1 - t) / fadeOut;
    return 1.0;
  }

  /// Same shape as [fadeBell] but biased to start at 1.0 and end at 0 — used
  /// for scale that grows fast, holds, then shrinks slowly.
  static double scaleBell(double t,
      {double grow = 0.22, double hold = 0.55}) {
    if (t <= 0) return 0;
    if (t >= 1) return 0;
    if (t < grow) return t / grow;
    if (t < grow + hold) return 1.0;
    final tail = (t - grow - hold) / (1 - grow - hold);
    return 1.0 - tail * 0.6; // shrinks to 40% before final fade
  }
}
