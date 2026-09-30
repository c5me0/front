// Dependency-injected volume, brightness, sharing, and photo-picker services. Tests and
// flow playback can use simulated adapters.

import 'package:flutter/widgets.dart';

import 'brightness_service.dart';
import 'photo_picker_service.dart';
import 'share_service.dart';
import 'volume_service.dart';

export 'brightness_service.dart';
export 'photo_picker_service.dart';
export 'share_service.dart';
export 'volume_service.dart';

@immutable
class DeviceServices {
  const DeviceServices({
    required this.volume,
    required this.brightness,
    required this.share,
    PhotoPickerService? photos,
  }) : _photos = photos;

  factory DeviceServices.system() => DeviceServices(
    volume: SystemVolumeService.shared,
    brightness: SystemBrightnessService.shared,
    share: SystemShareService.shared,
    photos: SystemPhotoPickerService.shared,
  );

  factory DeviceServices.simulated({
    double volume = 1,
    double brightness = 0.8,
  }) => DeviceServices(
    volume: SimulatedVolumeService(initial: volume),
    brightness: SimulatedBrightnessService(system: brightness),
    share: SimulatedShareService(),
    photos: SimulatedPhotoPickerService(),
  );

  final VolumeService volume;
  final BrightnessService brightness;
  final ShareService share;
  final PhotoPickerService? _photos;

  PhotoPickerService get photoPicker =>
      _photos ?? SystemPhotoPickerService.shared;
}

class DeviceServicesScope extends InheritedWidget {
  const DeviceServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final DeviceServices services;

  static DeviceServices? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DeviceServicesScope>()?.services;

  @override
  bool updateShouldNotify(DeviceServicesScope oldWidget) =>
      services != oldWidget.services;
}
