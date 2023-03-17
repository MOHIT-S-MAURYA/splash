import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VideoUploader extends StatefulWidget {
  final File videoFile;
  VideoUploader({required this.videoFile});

  @override
  _VideoUploaderState createState() => _VideoUploaderState();
}

class _VideoUploaderState extends State<VideoUploader> {
  double _uploadProgress = 0.0;
  late final FlutterFFmpeg _flutterFFmpeg;
  late final String _compressedFilePath;

  @override
  void initState() {
    super.initState();
    _flutterFFmpeg = FlutterFFmpeg();
    _compressVideo();
  }

  Future<void> _compressVideo() async {
    // Set output file path
    final tempDir = await getTemporaryDirectory();
    final outputFilePath = '${tempDir.path}/compressed.mp4';
    setState(() {
      _compressedFilePath = outputFilePath;
    });

    // Run FFmpeg command for lossless compression
    final arguments =
        '-i ${widget.videoFile.path} -c:v libx264 -preset ultrafast -crf 0 -c:a copy $outputFilePath';
    await _flutterFFmpeg.execute(arguments);
  }

  Future<void> _uploadVideo() async {
    // Create multipart request for uploading
    final request = http.MultipartRequest('POST', Uri.parse('YOUR_UPLOAD_URL'));

    // Add compressed video file to request
    final compressedVideoFile = File(_compressedFilePath);
    final videoStream = http.ByteStream(compressedVideoFile.openRead());
    final videoLength = await compressedVideoFile.length();
    final videoFileName = compressedVideoFile.path.split('/').last;
    final videoMultipartFile = http.MultipartFile(
        'video', videoStream, videoLength,
        filename: videoFileName);
    request.files.add(videoMultipartFile);

    // Send request and monitor progress
    final response = await request.send();
    response.stream.listen(
      (event) {
        final totalBytesSent = response.contentLength != null
            ? response.contentLength!
            : event.length;
        final bytesSent = event.length;
        final progress = bytesSent / totalBytesSent;
        setState(() {
          _uploadProgress = progress;
        });
      },
      onDone: () {
        print('Upload complete!');
      },
      onError: (error) {
        print('Upload failed: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Uploader'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
            LinearProgressIndicator(value: _uploadProgress),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _uploadProgress > 0.0 ? null : _uploadVideo,
            child: Text('Upload Video'),
          ),
        ],
      ),
    );
  }
}
