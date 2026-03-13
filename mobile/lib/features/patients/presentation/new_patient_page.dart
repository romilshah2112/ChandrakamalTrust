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
  static const int _maxImageBytes = 50 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _repo = PatientRepository();
  final _picker = ImagePicker();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _gender = TextEditingController();
  final _city = TextEditingController();
  final _birthDate = TextEditingController();
  final _password = TextEditingController();
  final _appUserId = TextEditingController();
  final _referenceTypeId = TextEditingController(text: '1');
  final _referenceName = TextEditingController();

  bool _saving = false;
  String? _message;
  String? _error;
  Uint8List? _profileImageBytes;
  String? _profileImageFileName;
  String? _profileImageContentType;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    _gender.dispose();
    _city.dispose();
    _birthDate.dispose();
    _password.dispose();
    _appUserId.dispose();
    _referenceTypeId.dispose();
    _referenceName.dispose();
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
              'Unable to compress image below 50KB. Please choose a smaller image.';
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
          gender: _gender.text.trim(),
          city: _city.text.trim(),
          birthDate: _birthDate.text.trim(),
          password: _password.text,
          imageName: null,
          imageBase64: _profileImageBytes == null
              ? null
              : base64Encode(_profileImageBytes!),
          imageFileName: _profileImageFileName,
          imageContentType: _profileImageContentType,
          appUserId: int.parse(_appUserId.text.trim()),
          referenceTypeId: int.parse(_referenceTypeId.text.trim()),
          referenceName: _referenceName.text.trim(),
        ),
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
      _gender.clear();
      _city.clear();
      _birthDate.clear();
      _password.clear();
      _appUserId.clear();
      _referenceTypeId.text = '1';
      _referenceName.clear();
      _clearSelectedImage();
    } catch (ex) {
      setState(() {
        _error = ex.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
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
              _field(_firstName, 'First Name'),
              _field(_lastName, 'Last Name'),
              _field(_mobile, 'Mobile No', numeric: true),
              _field(_email, 'Email'),
              _field(_address, 'Address'),
              _field(_gender, 'Gender'),
              _field(_city, 'City'),
              _field(_birthDate, 'Birth Date (YYYY-MM-DD)'),
              _field(_password, 'Password'),
              _imagePickerCard(),
              _field(_appUserId, 'App User Id (lAppUserId)', numeric: true),
              _field(_referenceTypeId, 'Reference Type Id', numeric: true),
              _field(_referenceName, 'Reference Name'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Picture',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a patient profile picture under 50KB.',
                style: Theme.of(context).textTheme.bodySmall,
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
