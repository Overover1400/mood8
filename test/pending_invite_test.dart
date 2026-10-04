import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/services/pending_invite_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final svc = PendingInviteService();

  test('friend invite link stores the code', () async {
    expect(
        await svc.captureFromUri(Uri.parse('https://mood8.app/r/HM9C7ND2')),
        isTrue);
    expect(await svc.peekRef(), 'HM9C7ND2');
  });

  test('challenge link keeps token and ref', () async {
    expect(
        await svc.captureFromUri(
            Uri.parse('https://mood8.app/c/tok123?ref=ABCD2345')),
        isTrue);
    expect(await svc.peekRef(), 'ABCD2345');
  });

  test('custom scheme links', () async {
    expect(await svc.captureFromUri(Uri.parse('mood8://invite?ref=ZZZZ2222')),
        isTrue);
    expect(await svc.peekRef(), 'ZZZZ2222');
    SharedPreferences.setMockInitialValues({});
    expect(
        await svc.captureFromUri(
            Uri.parse('mood8://challenge?token=t1&ref=QQQQ3333')),
        isTrue);
    expect(await svc.peekRef(), 'QQQQ3333');
  });

  test('web app query', () async {
    expect(
        await svc.captureFromUri(
            Uri.parse('https://mood8.app/app/?c=tok9&ref=WEBW4444')),
        isTrue);
    expect(await svc.peekRef(), 'WEBW4444');
  });

  test('first inviter wins, a later link cannot steal it', () async {
    await svc.captureFromUri(Uri.parse('https://mood8.app/r/FIRST222'));
    await svc.captureFromUri(Uri.parse('https://mood8.app/r/SECOND33'));
    expect(await svc.peekRef(), 'FIRST222');
  });

  test('unrelated links are ignored', () async {
    expect(await svc.captureFromUri(Uri.parse('https://example.com/r/ABC')),
        isFalse);
    expect(await svc.captureFromUri(Uri.parse('mood8://checkout-complete')),
        isFalse);
    expect(await svc.captureFromUri(Uri.parse('https://mood8.app/privacy')),
        isFalse);
    expect(await svc.peekRef(), isNull);
  });
}
