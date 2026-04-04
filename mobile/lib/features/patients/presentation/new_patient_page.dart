import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_create_request.dart';

class NewPatientPage extends StatefulWidget {
  const NewPatientPage({super.key});

  @override
  State<NewPatientPage> createState() => _NewPatientPageState();
}

class _NewPatientPageState extends State<NewPatientPage> {
  static const int _maxImageBytes = 100 * 1024;
  static const int _defaultReferenceTypeId = 6;
  static const String _defaultReferenceName = 'HealthCamp';

  final _formKey = GlobalKey<FormState>();
  final _repo = PatientRepository();
  final _picker = ImagePicker();

  static const List<String> _genderOptions = ['Male', 'Female', 'Transgender'];

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _age = TextEditingController();

  String? _selectedGender;

  bool _saving = false;
  String? _message;
  String? _error;
  Uint8List? _profileImageBytes;
  String? _profileImageFileName;
  String? _profileImageContentType;

  @override
  void initState() {
    super.initState();
  }

  String _ageToApiBirthDate(int age) {
    final year = DateTime.now().year - age;
    return '$year-01-01';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final source = await _chooseImageSource();
      if (source == null) {
        return;
      }

      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final compressed = await _compressImage(bytes);
      if (compressed == null || compressed.length > _maxImageBytes) {
        setState(() {
          _error =
              'Unable to compress image below 100KB. Please choose a smaller image.';
        });
        return;
      }

      final baseName = picked.name.contains('.')
          ? '${picked.name.split('.').first}.jpg'
          : '${picked.name}.jpg';

      setState(() {
        _profileImageBytes = compressed;
        _profileImageFileName = baseName;
        _profileImageContentType = 'image/jpeg';
        _error = null;
      });
    } catch (ex) {
      setState(() {
        _error = 'Image selection failed: $ex';
      });
    }
  }

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _compressImage(Uint8List source) async {
    if (source.length <= _maxImageBytes) {
      return source;
    }

    Uint8List current = source;
    for (final quality in const [85, 70, 55, 40, 30, 20]) {
      final result = await FlutterImageCompress.compressWithList(
        current,
        quality: quality,
        format: CompressFormat.jpeg,
        minWidth: 512,
        minHeight: 512,
      );
      current = Uint8List.fromList(result);
      if (current.length <= _maxImageBytes) {
        return current;
      }
    }

    return null;
  }

  void _clearSelectedImage() {
    setState(() {
      _profileImageBytes = null;
      _profileImageFileName = null;
      _profileImageContentType = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _error = 'Session expired. Please login again.';
      });
      return;
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      setState(() => _error = 'Please select Gender.');
      return;
    }
    final age = int.tryParse(_age.text.trim());
    if (age == null || age < 0 || age > 130) {
      setState(() => _error = 'Please enter a valid Age.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      await _repo.createPatient(
        accessToken: token,
        request: PatientCreateRequestModel(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          mobileNo: int.parse(_mobile.text.trim()),
          email: _email.text.trim(),
          address: _address.text.trim(),
          gender: _selectedGender!,
          city: _city.text.trim(),
          birthDate: _ageToApiBirthDate(age),
          imageName: null,
          imageBase64: _profileImageBytes == null
              ? null
              : base64Encode(_profileImageBytes!),
          imageFileName: _profileImageFileName,
          imageContentType: _profileImageContentType,
          referenceTypeId: _defaultReferenceTypeId,
          referenceName: _defaultReferenceName,
        ),
      );

      if (!mounted) {
        return;
      }

      await _showResultDialog(
        title: 'Success',
        message: 'Patient onboarded successfully.',
      );

      setState(() {
        _message = 'Patient onboarded successfully.';
      });
      _formKey.currentState!.reset();
      _firstName.clear();
      _lastName.clear();
      _mobile.clear();
      _email.clear();
      _address.clear();
      _city.clear();
      _age.clear();
      _selectedGender = null;
      _clearSelectedImage();
    } catch (ex) {
      final message = ex.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = message;
      });
      if (mounted) {
        await _showResultDialog(title: 'Error', message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _imagePickerCard(),
              _field(_firstName, 'First Name'),
              _field(_lastName, 'Last Name'),
              _field(_mobile, 'Mobile No', numeric: true),
              _field(_email, 'Email'),
              _field(_address, 'Address'),
              _genderDropdown(),
              _field(_city, 'City'),
              _field(_age, 'Age', numeric: true),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Patient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          border: OutlineInputBorder(),
        ),
        hint: const Text('Select Gender'),
        items: _genderOptions
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: _saving
            ? null
            : (value) {
                setState(() => _selectedGender = value);
              },
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          return null;
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (!required) {
            return null;
          }
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          if (numeric && int.tryParse(value.trim()) == null) {
            return 'Must be numeric';
          }
          if (label == 'Age') {
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed < 0 || parsed > 130) {
              return 'Enter a valid age';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _imagePickerCard() {
    final imageBytes = _profileImageBytes;
    final imageSize = imageBytes == null
        ? null
        : (imageBytes.length / 1024).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Photo (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a patient photo under 100KB if available.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (imageBytes != null) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_profileImageFileName ?? 'profile.jpg'} • ${imageSize ?? '0'} KB',
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _pickProfileImage,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      imageBytes == null ? 'Upload Picture' : 'Change Picture',
                    ),
                  ),
                  if (imageBytes != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saving ? null : _clearSelectedImage,
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
