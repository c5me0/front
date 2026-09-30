import 'package:cameo/content/lab.g.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CapturedPhoto (RN captureStore CapturedPhoto 와 같은 필드)', () {
    test(
      'placeholder = content camera-placeholder.jpg 768 x 1024 · source placeholder',
      () {
        final p = CapturedPhoto.placeholder();
        expect(p.uri, LabImages.cameraPlaceholder);
        expect(p.uri, labCamera.placeholder);
        expect(p.width, 768);
        expect(p.height, 1024);
        expect(p.aspectRatio, 0.75);
        expect(p.source, CapturedPhotoSource.placeholder);
        expect(p.image, isA<AssetImage>());
        expect((p.image as AssetImage).assetName, LabImages.cameraPlaceholder);
      },
    );

    test('camera 결과 → FileImage(uri)', () {
      const p = CapturedPhoto(
        uri: '/tmp/cameo/photo.jpg',
        width: 3024,
        height: 4032,
        source: CapturedPhotoSource.camera,
      );
      expect(p.image, isA<FileImage>());
      expect((p.image as FileImage).file.path, '/tmp/cameo/photo.jpg');
      expect(p.aspectRatio, 0.75);
    });

    test('값 동등성', () {
      expect(CapturedPhoto.placeholder(), CapturedPhoto.placeholder());
      expect(
        CapturedPhoto.placeholder().hashCode,
        CapturedPhoto.placeholder().hashCode,
      );
      expect(
        CapturedPhoto.placeholder() ==
            const CapturedPhoto(
              uri: 'x',
              width: 768,
              height: 1024,
              source: CapturedPhotoSource.placeholder,
            ),
        isFalse,
      );
    });
  });
}
