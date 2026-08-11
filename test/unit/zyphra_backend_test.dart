import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/infrastructure/zyphra/zyphra_backend.dart';

void main() {
  group('ZyphraBackend.resolveVoice', () {
    test('maps the Kokoro default voice to the Zyphra default', () {
      expect(ZyphraBackend.resolveVoice('af_heart'), 'american-female-2');
    });

    test('maps any Kokoro voice id to the Zyphra default', () {
      expect(ZyphraBackend.resolveVoice('am_adam'), 'american-female-2');
      expect(ZyphraBackend.resolveVoice('bf_emma'), 'american-female-2');
    });

    test('passes Zyphra voice ids through unchanged', () {
      expect(
        ZyphraBackend.resolveVoice('british-female-2'),
        'british-female-2',
      );
      expect(ZyphraBackend.resolveVoice('american-male'), 'american-male');
    });
  });
}
