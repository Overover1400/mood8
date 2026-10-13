import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/feature_flags.dart';
import 'package:mood8/services/stepping_stone_service.dart';

void main() {
  test('the third miss no longer parks a habit (ask-why loop owns it)', () {
    expect(kSteppingStoneParkingEnabled, isFalse);
    // Returns before touching any storage, so no Hive is needed.
    expect(SteppingStoneService().pickCandidate(), isNull);
  });
}
