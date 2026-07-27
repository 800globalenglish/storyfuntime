import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';

class _AgeStage {
  final String label;
  final String ageRange;
  final bool isChild;
  const _AgeStage({
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
    _AgeStage(label: 'Infant', ageRange: '0-1', isChild: true),
    _AgeStage(label: 'Toddler', ageRange: '2-5', isChild: true),
    _AgeStage(label: 'Child', ageRange: '6-10', isChild: true),
    _AgeStage(label: 'Preteen', ageRange: '11-15', isChild: true),
    _AgeStage(label: 'Teenager', ageRange: '16-21', isChild: true),
    _AgeStage(label: 'Young Adult', ageRange: '22-35', isChild: false),
    _AgeStage(label: 'Adult', ageRange: '36-45', isChild: false),
    _AgeStage(label: 'Middle-Aged', ageRange: '46-65', isChild: false),
    _AgeStage(label: 'Senior', ageRange: '66-80', isChild: false),
    _AgeStage(label: 'Elder', ageRange: '81-115', isChild: false),
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

  @override
  void initState() {
    super.initState();
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    super.dispose();
  }

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
          _errorMessage = AppStrings.t('please_enter_name');
        });
        return;
      }
      if (_pickedImage == null) {
        setState(() {
          _errorMessage = AppStrings.t('please_choose_photo');
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
        _errorMessage = '${AppStrings.t('error_prefix')} \$e';
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('add_a_character_title'))),
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
                      label: Text(AppStrings.t('take_photo')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: Text(AppStrings.t('open_gallery')),
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
                decoration: InputDecoration(
                  labelText: AppStrings.t('name_label'),
                  border: const OutlineInputBorder(),
                  hintText: AppStrings.t('name_hint'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'Human', label: Text(AppStrings.t('human'))),
                    ButtonSegment(value: 'Pet', label: Text(AppStrings.t('pet'))),
                  ],
                  selected: {_characterType},
                  onSelectionChanged: (newSelection) {
                    setState(() => _characterType = newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildGenderOption('female', 'female.png', AppStrings.t('female')),
                    _buildGenderOption('male', 'male.png', AppStrings.t('male')),
                    if (_characterType == 'Human')
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<int>(
                          value: _ageStageIndex,
                          decoration: InputDecoration(
                            labelText: AppStrings.t('age_label'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (int i = 0; i < _ageStages.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(_ageStages[i].ageRange),
                              ),
                          ],
                          onChanged: (value) => setState(() => _ageStageIndex = value ?? 0),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_avatarUrl != null) ...[
              Text(AppStrings.t('heres_your_character')),
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
                labelText: _avatarUrl == null ? AppStrings.t('optional_instructions') : AppStrings.t('instructions_for_next_try'),
                hintText: AppStrings.t('avatar_instructions_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSaving)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(AppStrings.t('working_on_it')),
                ],
              )
            else ...[
              ElevatedButton(
                onPressed: _generate,
                child: Text(_avatarUrl == null ? AppStrings.t('generate_character') : AppStrings.t('regenerate')),
              ),
              if (_avatarUrl != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppStrings.t('done')),
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