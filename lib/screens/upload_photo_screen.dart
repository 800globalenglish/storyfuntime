import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

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
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => Scaffold(
        backgroundColor: ThemeController.instance.backgroundData.color,
        appBar: AppBar(
          centerTitle: true,
          title: Text('Photo for Page ${widget.pageNumber}'),
          actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pickedImage == null && _cartoonImageUrl == null)
              SizedBox(
                height: _buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeController.instance.buttonColor(ButtonRole.primary),
                    foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.primary),
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  icon: const Icon(Icons.photo_library, size: 32),
                  label: const Text('Choose a Photo', style: TextStyle(fontSize: 22)),
                ),
              ),
            if (_pickedImage != null && _cartoonImageUrl == null) ...[
              Text(
                'Selected: ${_pickedImage!.name}',
                style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
              ),
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
                      child: SizedBox(
                        height: _buttonHeight,
                        child: ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                            foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          child: const Text('Choose Different Photo', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: _buttonHeight,
                        child: ElevatedButton(
                          onPressed: _uploadAndCartoonize,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                            foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          child: const Text('Cartoonize It', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            if (_cartoonImageUrl != null) ...[
              Text(
                'Here\'s the cartoon version:',
                style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
              ),
              const SizedBox(height: 12),
              Image.network('${ApiService.baseUrl}$_cartoonImageUrl'),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cartoonImageUrl != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: _buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            const DebugScreenTag('upload_photo_screen.dart'),
          ],
        ),
      ),
      ),
    );
  }
}
