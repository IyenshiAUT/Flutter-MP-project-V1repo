import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mediapipe/image_paint.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: MyHomePage(cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyHomePage({super.key, required this.cameras});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final channel = const MethodChannel("flutter_mediapipe");
  final picker = ImagePicker();
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  XFile? image;
  List<Offset> points = [];
  List<List<Offset>> lines = [];
  Size viewSize = const Size(250, 250);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final camera = widget.cameras.first;
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile capturedImage = await _controller.takePicture();
      setState(() {
        image = capturedImage;
        _isCapturing = false;
      });
      handMarker();
    } catch (e) {
      print('Error capturing image: $e');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  void handMarker() async {
    if (image == null) return;

    try {
      var bytes = await image?.readAsBytes();
      var result = await channel.invokeMethod("handMarker", {
        "width": viewSize.width.toInt(),
        "height": viewSize.height.toInt(),
        "bytes": bytes
      });

      var dataPoints = result["points"] as List<dynamic>;
      var dataLines = result["lines"] as List<dynamic>;

      setState(() {
        points = dataPoints.map((point) => Offset(point[0], point[1])).toList();
        lines = dataLines
            .map((lines) => [
                  Offset(lines[0][0], lines[0][1]),
                  Offset(lines[1][0], lines[1][1]),
                ])
            .toList();
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!_isCameraInitialized)
              const CircularProgressIndicator()
            else if (image == null)
              Container(
                width: viewSize.width,
                height: viewSize.height,
                decoration: BoxDecoration(border: Border.all()),
                margin: const EdgeInsets.all(20.0),
                child: CameraPreview(_controller),
              )
            else
              Container(
                width: viewSize.width,
                height: viewSize.height,
                decoration: BoxDecoration(border: Border.all()),
                margin: const EdgeInsets.all(20.0),
                child: Image(image: FileImage(File(image!.path))),
              ),
            if (image == null)
              ElevatedButton(
                onPressed: _isCapturing ? null : _captureImage,
                child: Text(_isCapturing ? "Capturing..." : "CAPTURE"),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        image = null;
                        points = [];
                        lines = [];
                      });
                    },
                    child: const Text("NEW PHOTO"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: handMarker,
                    child: const Text("MARKER"),
                  ),
                ],
              ),
            if (image != null)
              Container(
                width: viewSize.width,
                height: viewSize.height,
                decoration: BoxDecoration(border: Border.all()),
                margin: const EdgeInsets.all(20.0),
                child: CustomPaint(
                  painter: ImagePainter(points: points, lines: lines),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
