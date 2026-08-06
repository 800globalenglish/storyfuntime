import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../widgets/voice_text_field.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

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

  Widget _buildGenderOption(String value, String asset, String label, Color primaryColor, Color secondaryColor) {
    final selected = _genderSelection == value;
    // Colored circle background: female = theme primary, male = theme secondary. Icon stays white on top.
    final circleColor = value == 'female' ? primaryColor : secondaryColor;
    return GestureDetector(
      onTap: () => setState(() => _genderSelection = value),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleColor,
              border: Border.all(
                color: selected ? Colors.deepPurple : Colors.transparent,
                width: 3,
              ),
            ),
            child: Icon(
              value == 'female' ? Icons.woman : Icons.man,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 22, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('add_character_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          AppStrings.t('add_a_character_title'),
          style: const TextStyle(fontSize: 22),
        ),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ValueListenableBuilder<AppThemeKey>(
          valueListenable: ThemeController.instance.current,
          builder: (context, themeKey, _) {
            final themeData = kAppThemes[themeKey]!;
            return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_characterId == null) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeData.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 32),
                        label: Text(
                          AppStrings.t('take_photo'),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: _buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeData.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                        ),
                        icon: const Icon(Icons.photo_library, size: 32),
                        label: Text(
                          AppStrings.t('open_gallery'),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
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
              VoiceTextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
                micColor: themeData.primary,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: AppStrings.t('name_label'),
                  hintStyle: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'Human',
                      label: Text(AppStrings.t('human'), style: const TextStyle(fontSize: 22)),
                    ),
                    ButtonSegment(
                      value: 'Pet',
                      label: Text(AppStrings.t('pet'), style: const TextStyle(fontSize: 22)),
                    ),
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
                    _buildGenderOption('female', 'female.png', AppStrings.t('female'), themeData.primary, themeData.secondary),
                    _buildGenderOption('male', 'male.png', AppStrings.t('male'), themeData.primary, themeData.secondary),
                    if (_characterType == 'Human')
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<int>(
                          value: _ageStageIndex,
                          style: const TextStyle(fontSize: 22, color: Colors.black),
                          decoration: InputDecoration(
                            labelText: AppStrings.t('age_label'),
                            labelStyle: const TextStyle(fontSize: 22),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (int i = 0; i < _ageStages.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  _ageStages[i].ageRange,
                                  style: const TextStyle(fontSize: 22),
                                ),
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
              Text(
                AppStrings.t('heres_your_character'),
                style: const TextStyle(fontSize: 22),
              ),
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
            VoiceTextField(
              controller: _instructionsController,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22),
              micColor: themeData.accent,
              decoration: InputDecoration(
                hintText: _avatarUrl == null
                    ? AppStrings.t('optional_instructions')
                    : AppStrings.t('instructions_for_next_try'),
                hintStyle: const TextStyle(fontSize: 22),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSaving)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.t('working_on_it'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: _buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeData.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 28),
                  label: Text(
                    _avatarUrl == null ? AppStrings.t('generate_character') : AppStrings.t('regenerate'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              if (_avatarUrl != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: _buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                    ),
                    icon: const Icon(Icons.check, size: 28),
                    label: Text(
                      AppStrings.t('done'),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 22)),
            ],
          ],
            );
          },
        ),
      ),
    );
  }
}