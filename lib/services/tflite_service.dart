import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  late Interpreter _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('model.tflite');
    _inputShape = _interpreter.getInputTensor(0).shape;
    _outputShape = _interpreter.getOutputTensor(0).shape;
  }

  Uint8List preprocessImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Image decoding failed");

    img.Image resizedImage = img.copyResize(image, width: _inputShape[1], height: _inputShape[2]);

    List<double> normalizedPixels = resizedImage
        .getBytes()
        .map((pixel) => pixel / 255.0)
        .toList();

    return Uint8List.fromList(normalizedPixels.map((e) => (e * 255).toInt()).toList());
  }

  bool predict(Uint8List inputImage) {
    var input = inputImage.buffer.asUint8List();
    var output = List.filled(1, 0).reshape([1]);

    _interpreter.run(input, output);
    final prediction = output[0][0];

    return prediction > 0.5;
  }

  void close() {
    _interpreter.close();
  }
}
