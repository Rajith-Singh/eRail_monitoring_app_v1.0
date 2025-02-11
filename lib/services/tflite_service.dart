import 'dart:typed_data';
import 'dart:convert';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_4/opencv_4.dart';

class TFLiteService {
  late Interpreter _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;

  Future<void> loadModel() async {
    try {
      print("Loading model...");
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;

      print("Model loaded successfully with input shape: $_inputShape");
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  Float32List preprocessImage(Uint8List imageBytes) {
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Image decoding failed");

    print("Original image size: ${image.width} x ${image.height}");

    // Resize the image to 640x640
    img.Image resized = img.copyResize(image, width: 640, height: 640);

    // Create a Float32List for model input
    var float32Pixels = Float32List(640 * 640 * 3);
    int index = 0;

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        img.Pixel pixel = resized.getPixel(x, y); // Get Pixel object

        // Extract RGB values directly
        int red = pixel.r.toInt();
        int green = pixel.g.toInt();
        int blue = pixel.b.toInt();

        // Normalize pixel values to [0,1] range
        float32Pixels[index++] = red / 255.0;
        float32Pixels[index++] = green / 255.0;
        float32Pixels[index++] = blue / 255.0;
      }
    }

    print("Preprocessed image size: ${float32Pixels.length}");
    return float32Pixels;
  }

  /// Predicts defects and returns structured JSON output
  String predict(Float32List inputImage) {
    var input = inputImage.reshape([1, 640, 640, 3]); // Ensure correct shape
    print("Input shape to model: ${input.shape}");

    var output = List.generate(
      _outputShape.reduce((a, b) => a * b),
      (index) => 0.0,
    ).reshape(_outputShape);

    _interpreter.run(input, output);

    print("Raw model output: $output");

    // **Extract Predictions**
    List<dynamic> predictions = output[0];

    List<Map<String, dynamic>> formattedPredictions = [];

    // Iterate through the model output and extract bounding box, confidence, and class
    for (var pred in predictions) {
      if (pred is List<dynamic> && pred.length >= 6) {
        double xmin = pred[0];  // Extract xmin from model output
        double ymin = pred[1];  // Extract ymin from model output
        double xmax = pred[2];  // Extract xmax from model output
        double ymax = pred[3];  // Extract ymax from model output
        double confidence = pred[4];  // Confidence score
        int classLabel = pred[5].toInt(); // Class ID (0 = defective, 1 = normal)

        formattedPredictions.add({
          "class": classLabel,
          "confidence": confidence,
          "xmin": xmin,
          "ymin": ymin,
          "xmax": xmax,
          "ymax": ymax,
        });
      }
    }

    // Convert to JSON
    Map<String, dynamic> result = {
      "predictions": formattedPredictions,
    };

    String jsonString = jsonEncode(result);
    print("Formatted Prediction JSON: $jsonString");

    return jsonString;
  }


  void close() {
    _interpreter.close();
  }
}
