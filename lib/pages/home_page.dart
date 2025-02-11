import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  late TFLiteService _tfliteService;
  bool _isDefective = false;
  String _statusMessage = "Initializing...";
  bool _isCameraInitialized = false;  // Camera initialization flag
  bool _isModelInitialized = false;   // Model initialization flag

  @override
  void initState() {
    super.initState();
    _initializeModel(); // Initialize model first
  }

  // Initialize model
  Future<void> _initializeModel() async {
    try {
      print("Initializing model...");
      _tfliteService = TFLiteService();
      await _tfliteService.loadModel();

      if (mounted) {
        setState(() {
          _isModelInitialized = true;
          _updateStatusMessage();
        });
      }
      print("Model loaded successfully.");
      _initializeCamera(); // Initialize camera after model
    } catch (e) {
      print("Error loading model: $e");
      setState(() {
        _statusMessage = "Error loading model";
      });
    }
  }

  // Update status message based on camera and model initialization
  void _updateStatusMessage() {
    if (_isCameraInitialized && _isModelInitialized) {
      setState(() {
        _statusMessage = "Ready for detection";  // Update status when both are initialized
      });
    }
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras.first, ResolutionPreset.medium);
    
    // Start camera initialization
    await _cameraController?.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
        _updateStatusMessage();
      });
    }

    print("Camera initialized successfully.");
    _startRealTimeDetection();
  }

  // Real-time detection loop: take pictures every 2 seconds
  Future<void> _startRealTimeDetection() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 2));
      if (_cameraController!.value.isInitialized && _isModelInitialized) {
        final image = await _cameraController!.takePicture();
        print("Captured an image: ${image.path}");
        await _detectDefects(await image.readAsBytes());
      }
    }
  }

  // Detect defects in the captured image

  Future<void> _detectDefects(Uint8List imageBytes) async {
    try {
      if (!_isModelInitialized) {
        print("Model not initialized yet.");
        return;
      }

      print("Preprocessing image...");
      final processedImage = _tfliteService.preprocessImage(imageBytes);
      print("Image preprocessed successfully.");

      print("Making prediction...");
      String predictionJson = _tfliteService.predict(processedImage);

      // Parse JSON
      Map<String, dynamic> predictionData = jsonDecode(predictionJson);

      // Extract class label (0 = defective, 1 = normal)
      int classLabel = predictionData["predictions"][0]["class"];
      double confidence = predictionData["predictions"][0]["confidence"];

      // Determine if track is defective
      bool isDefectiveTrack = (classLabel == 0); // 0 means defective, 1 means normal

      setState(() {
        _isDefective = isDefectiveTrack;
        _statusMessage = _isDefective
            ? "Defective Track Detected! Confidence: ${confidence.toStringAsFixed(2)}"
            : "Track is Normal. Confidence: ${confidence.toStringAsFixed(2)}";
      });

      print("Prediction completed: $_statusMessage");
    } catch (e) {
      print("Error during prediction: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E-Rail Track Monitoring'),
        backgroundColor: _isDefective ? Colors.red : Colors.green,
        centerTitle: true,
      ),
      body: _cameraController?.value.isInitialized ?? false
          ? Stack(
              children: [
                CameraPreview(_cameraController!),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _isDefective ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tfliteService.close();
    super.dispose();
  }
}
