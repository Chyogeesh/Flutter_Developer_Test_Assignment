import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class RecordVideoScreen extends StatefulWidget {
  @override
  _RecordVideoScreenState createState() => _RecordVideoScreenState();
}

class _RecordVideoScreenState extends State<RecordVideoScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  String? _videoPath;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String? _location;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras![0], ResolutionPreset.high);
    await _controller!.initialize();
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _location = '${position.latitude}, ${position.longitude}';
    });
  }

  Future<void> _startRecording() async {
    if (_controller != null && !_controller!.value.isRecordingVideo) {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_controller != null && _controller!.value.isRecordingVideo) {
      XFile videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoPath != null) {
      File videoFile = File(_videoPath!);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(fileName).putFile(videoFile);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('videos').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _categoryController.text,
        'location': _location,
        'url': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _videoPath = null;
        _titleController.clear();
        _descriptionController.clear();
        _categoryController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video uploaded successfully')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Video'),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
            ],
          ),
          if (_videoPath != null)
            Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(labelText: 'Category'),
                ),
                ElevatedButton(
                  onPressed: _uploadVideo,
                  child: Text('Upload Video'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
