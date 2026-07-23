import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AddCharacterScreen extends StatefulWidget {
  final String bookId;

  const AddCharacterScreen({super.key, required this.bookId});

  @override
  State<AddCharacterScreen> createState() => _AddCharacterScreenState();
}

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final _apiService = ApiService();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _role = 'Grandchild';
  String _gender = 'boy';
  String _ageRange = '0-2';
  XFile? _pickedImage;
  bool _isSaving = false;
  String? _errorMessage;
  String? _avatarUrl;
  String? _characterId;

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
        _errorMessage = null;
      });
    }
  }

  Future<void> _generate() async {
    if (_avatarUrl == null) {
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a name.';
        });
        return;
      }
      if (_pickedImage == null) {
        setState(() {
          _errorMessage = 'Please choose a photo.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_characterId == null) {
        final bytes = await _pickedImage!.readAsBytes();
        final character = await _apiService.addCharacter(
          bookId: widget.bookId,
          name: _nameController.text.trim(),
          role: _role,
          gender: _gender,
          ageRange: _ageRange,
          extraInstructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
          photoBytes: bytes,
          fileName: _pickedImage!.name,
        );
        setState(() {
          _characterId = character.id;
          _avatarUrl = character.cartoonAvatarUrl;
        });
      } else {
        final character = await _apiService.regenerateCharacterAvatar(
          characterId: _characterId!,
          extraInstructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );
        setState(() {
          _avatarUrl = character.cartoonAvatarUrl;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Character')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_characterId == null) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Grandma, Buddy',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Grandma', child: Text('Grandma')),
                  DropdownMenuItem(value: 'Grandpa', child: Text('Grandpa')),
                  DropdownMenuItem(value: 'Grandchild', child: Text('Grandchild')),
                  DropdownMenuItem(value: 'Pet', child: Text('Pet')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _role = value ?? 'Grandchild';
                    _gender = _role == 'Pet' ? 'male animal' : 'boy';
                    _ageRange = _role == 'Grandma' || _role == 'Grandpa' ? '40-50' : '0-2';
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_role != 'Pet')
                DropdownButtonFormField<String>(
                  initialValue: _ageRange,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  items: (_role == 'Grandma' || _role == 'Grandpa')
                      ? const [
                    DropdownMenuItem(value: '40-50', child: Text('40-50')),
                    DropdownMenuItem(value: '51-65', child: Text('51-65')),
                    DropdownMenuItem(value: '66-80', child: Text('66-80')),
                    DropdownMenuItem(value: '81+', child: Text('81+')),
                  ]
                      : const [
                    DropdownMenuItem(value: '0-2', child: Text('0-2 (baby/toddler)')),
                    DropdownMenuItem(value: '3-5', child: Text('3-5')),
                    DropdownMenuItem(value: '6-9', child: Text('6-9')),
                    DropdownMenuItem(value: '10-13', child: Text('10-13')),
                    DropdownMenuItem(value: '14-18', child: Text('14-18')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _ageRange = value ?? '0-2';
                    });
                  },
                ),
              if (_role != 'Pet') const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: _role == 'Pet'
                    ? const [
                        DropdownMenuItem(value: 'male animal', child: Text('Male')),
                        DropdownMenuItem(value: 'female animal', child: Text('Female')),
                      ]
                    : const [
                        DropdownMenuItem(value: 'boy', child: Text('Boy')),
                        DropdownMenuItem(value: 'girl', child: Text('Girl')),
                        DropdownMenuItem(value: 'man', child: Text('Man')),
                        DropdownMenuItem(value: 'woman', child: Text('Woman')),
                      ],
                onChanged: (value) {
                  setState(() {
                    _gender = value ?? (_role == 'Pet' ? 'male animal' : 'boy');
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_pickedImage == null)
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose a Photo'),
                )
              else ...[
                Text('Selected: ${_pickedImage!.name}'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pickImage,
                  child: const Text('Choose Different Photo'),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (_avatarUrl != null) ...[
              const Text('Here\'s the cartoon avatar:'),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      'http://localhost:5220$_avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _instructionsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _avatarUrl == null ? 'Optional instructions' : 'Instructions for next try',
                hintText: 'e.g. make the hair darker, keep it a dog not a person',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSaving)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Working on it... this can take up to 30 seconds.'),
                ],
              )
            else ...[
              ElevatedButton(
                onPressed: _generate,
                child: Text(_avatarUrl == null ? 'Generate Avatar' : 'Regenerate'),
              ),
              if (_avatarUrl != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Done'),
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
