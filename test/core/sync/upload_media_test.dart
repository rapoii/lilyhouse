import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/sync/sync_service.dart';

void main() {
  test('SyncService.uploadMedia uploads base64 image and returns Drive URL', () async {
    final syncService = SyncService(
      endpointUrl: 'https://script.google.com/macros/s/AKfycbxLnaF6AG1Ag06TD2MDp0Tws45ZOlVC9NJNdQKmYMGg6gy1OQmJfZVdkuX0hD9xfoz9ug/exec',
    );
    // 10x10 pink png
    const pinkPng = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC';

    final url = await syncService.uploadMedia(
      fileName: 'dart_test_furina.png',
      base64Data: pinkPng,
      mimeType: 'image/png',
    );

    expect(url, isNotNull);
    expect(url, startsWith('https://drive.google.com/'));
    print('Uploaded image Google Drive URL: $url');
  });
}
