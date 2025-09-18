import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class SelectedImageNotifier extends StateNotifier<XFile?> {
  SelectedImageNotifier() : super(null);

  void setImage(XFile image) {
    state = image;
  }

  void clearImage() {
    state = null;
  }
}

final selectedImageProvider = StateNotifierProvider<SelectedImageNotifier, XFile?>(
  (ref) => SelectedImageNotifier(),
);