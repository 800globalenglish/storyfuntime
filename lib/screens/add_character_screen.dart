import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class _AgeStage {
  final String asset;
  final String label;
  final String ageRange;
  final bool isChild;
  const _AgeStage({
    required this.asset,
    required this.label,
    required this.ageRange,
    required this.isChild,
  });
}

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

  final List<_AgeStage> _ageStages = const [
    _AgeStage(asset: 'age_01_sm.png', label: 'Baby', ageRange: '0-2', isChild: true),
    _AgeStage(asset: 'age_02_sm.png', label: 'Child', ageRange: '3-9', isChild: true),
    _AgeStage(asset: 'age_03_sm.png', label: 'Teenager', ageRange: '10-18', isChild: true),
    _AgeStage(asset: 'age_04_sm.png', label: 'Young Adult', ageRange: '19-39', isChild: false),
    _AgeStage(asset: 'age_05_sm.png', label: 'Adult', ageRange: '40-65', isChild: false),
    _AgeStage(asset: 'age_06_sm.png', label: 'Senior', ageRange: '66-80', isChild: false),
    _AgeStage(asset: 'age_07_sm.png', label: 'Elder', ageRange: '81+', isChild: false),
  ];

  String _characterType = 'Human'; // 'Human' or 'Pet'
  String _genderSelection = 'female'; // 'male' or 'female'
  int _ageStageIndex = 0;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _isSaving = false;
  String? _errorMessage;
  String? _avatarUrl;
  String? _characterId;

  // Translates the current selections into the exact strings the backend expects.
  String get _resolvedRole {
    if (_characterType == 'Pet') return 'Pet';
    return _ageStages[_ageStageIndex].label;
  }

  String get _resolvedGender {
    if (_characterType == 'Pet') {
      return _genderSelection == 'male' ? 'male animal' : 'female animal';
    }
    final isChild = _ageStages[_ageStageIndex].isChild;
    if (isChild) {
      return _genderSelection == 'male' ? 'boy' : 'girl';
    }
    return _genderSelection == 'male' ? 'man' : 'woman';
  }

  String get _resolvedAgeRange {
    if (_characterType == 'Pet') return 'N/A';
    return _ageStages[_ageStageIndex].ageRange;
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
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
          role: _resolvedRole,
          gender: _resolvedGender,
          ageRange: _resolvedAgeRange,
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

  Widget _buildGenderOption(String value, String asset, String label) {
    final selected = _genderSelection == value;
    return GestureDetector(
      onTap: () => setState(() => _genderSelection = value),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.deepPurple : Colors.transparent,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: Image.asset('assets/images/$asset', width: 50, height: 50, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildAgeStageOption(int index) {
    final stage = _ageStages[index];
    final selected = _ageStageIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _ageStageIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.deepPurple : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipOval(
            child: Image.asset('assets/images/${stage.asset}', width: 35, height: 35, fit: BoxFit.cover),
          ),
        ),
      ),
    );
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Open Gallery'),
                    ),
                  ),
                ],
              ),
              if (_pickedImageBytes != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _pickedImageBytes!,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Grandma, Buddy',
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Human', label: Text('Human')),
                    ButtonSegment(value: 'Pet', label: Text('Pet')),
                  ],
                  selected: {_characterType},
                  onSelectionChanged: (newSelection) {
                    setState(() => _characterType = newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGenderOption('female', 'female.png', 'Female'),
                    const SizedBox(width: 32),
                    _buildGenderOption('male', 'male.png', 'Male'),
                  ],
                ),
              ),
              if (_characterType == 'Human') ...[
                const SizedBox(height: 20),
                const Text('Age', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_ageStages.length, _buildAgeStageOption),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            if (_avatarUrl != null) ...[
              const Text('Here\'s your character:'),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '${ApiService.baseUrl}$_avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}',
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
                child: Text(_avatarUrl == null ? 'Generate Character' : 'Regenerate'),
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