import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  late TFLiteService _tfliteService;
  bool _isDefective = false;
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeModel();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras.first, ResolutionPreset.medium);
    await _cameraController?.initialize();
    if (mounted) setState(() {});
    _startRealTimeDetection();
  }

  Future<void> _initializeModel() async {
    _tfliteService = TFLiteService();
    await _tfliteService.loadModel();
  }

  Future<void> _startRealTimeDetection() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 2));
      if (_cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();
        await _detectDefects(await image.readAsBytes());
      }
    }
  }

  Future<void> _detectDefects(Uint8List imageBytes) async {
    final processedImage = _tfliteService.preprocessImage(imageBytes);
    final isDefective = _tfliteService.predict(processedImage);

    setState(() {
      _isDefective = isDefective;
      _statusMessage = _isDefective ? "Defective Track Detected!" : "Track is Normal";
    });
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
