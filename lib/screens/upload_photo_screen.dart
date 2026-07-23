import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class UploadPhotoScreen extends StatefulWidget {
  final String pageId;
  final int pageNumber;

  const UploadPhotoScreen({
    super.key,
    required this.pageId,
    required this.pageNumber,
  });

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends State<UploadPhotoScreen> {
  final _apiService = ApiService();
  final _picker = ImagePicker();

  XFile? _pickedImage;
  bool _isUploading = false;
  String? _errorMessage;
  String? _cartoonImageUrl;

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null;
      _cartoonImageUrl = null;
    });

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _uploadAndCartoonize() async {
    if (_pickedImage == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final page = await _apiService.uploadPhoto(
        pageId: widget.pageId,
        photoBytes: bytes,
        fileName: _pickedImage!.name,
      );
      setState(() {
        _cartoonImageUrl = page.cartoonImageUrl;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Photo for Page ${widget.pageNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pickedImage == null && _cartoonImageUrl == null)
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose a Photo'),
              ),
            if (_pickedImage != null && _cartoonImageUrl == null) ...[
              Text('Selected: ${_pickedImage!.name}'),
              const SizedBox(height: 16),
              if (_isUploading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Turning this into a cartoon... this can take up to 30 seconds.'),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickImage,
                        child: const Text('Choose Different Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _uploadAndCartoonize,
                        child: const Text('Cartoonize It'),
                      ),
                    ),
                  ],
                ),
            ],
            if (_cartoonImageUrl != null) ...[
              const Text('Here\'s the cartoon version:'),
              const SizedBox(height: 12),
              Image.network('http://localhost:5220$_cartoonImageUrl'),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _cartoonImageUrl != null
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ),
      )
          : null,
    );
  }
}
