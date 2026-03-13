import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_data_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';

class PatientEditPage extends StatefulWidget {
  const PatientEditPage({
    super.key,
    required this.patientDataId,
    required this.patient,
  });

  final int patientDataId;
  final PatientDetailModel patient;

  @override
  State<PatientEditPage> createState() => _PatientEditPageState();
}

class _PatientEditPageState extends State<PatientEditPage> {
  static const int _maxImageBytes = 50 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _repo = PatientRepository();
  final _picker = ImagePicker();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _gender;
  late final TextEditingController _city;
  late final TextEditingController _birthDate;
  late final TextEditingController _referenceTypeId;
  late final TextEditingController _referenceName;

  bool _saving = false;
  String? _error;
  bool _isActive = true;
  Uint8List? _profileImageBytes;
  String? _profileImageFileName;
  String? _profileImageContentType;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _firstName = TextEditingController(text: p.firstName);
    _lastName = TextEditingController(text: p.lastName);
    _mobile = TextEditingController(text: '${p.mobileNo}');
    _email = TextEditingController(text: p.email);
    _address = TextEditingController(text: p.address);
    _gender = TextEditingController(text: p.gender);
    _city = TextEditingController(text: p.city);
    _birthDate = TextEditingController(text: p.birthDate);
    _referenceTypeId = TextEditingController(text: '${p.referenceTypeId}');
    _referenceName = TextEditingController(text: p.referenceName);
    _isActive = p.isActive;
    _currentImageUrl = p.imageName.isEmpty ? null : p.imageName;
  }

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

  void _removeSelectedImage() {
    setState(() {
      _profileImageBytes = null;
      _profileImageFileName = null;
      _profileImageContentType = null;
      _currentImageUrl = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _error = 'Session expired. Please login again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.updatePatient(
        accessToken: token,
        patientDataId: widget.patientDataId,
        request: PatientDataUpdateRequestModel(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          mobileNo: int.parse(_mobile.text.trim()),
          email: _email.text.trim(),
          address: _address.text.trim(),
          gender: _gender.text.trim(),
          city: _city.text.trim(),
          birthDate: _birthDate.text.trim(),
          imageName: _profileImageBytes == null ? _currentImageUrl : null,
          imageBase64: _profileImageBytes == null
              ? null
              : base64Encode(_profileImageBytes!),
          imageFileName: _profileImageFileName,
          imageContentType: _profileImageContentType,
          referenceTypeId: int.parse(_referenceTypeId.text.trim()),
          referenceName: _referenceName.text.trim(),
          isActive: _isActive,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (ex) {
      setState(() {
        _error = ex.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _imageSection(),
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Must be numeric';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _birthDate,
                decoration: const InputDecoration(
                  labelText: 'Birth date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _referenceTypeId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reference type ID',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Must be numeric';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _referenceName,
                decoration: const InputDecoration(
                  labelText: 'Reference name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
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
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Center(
            child: _profileImageBytes != null
                ? CircleAvatar(
                    radius: 52,
                    backgroundImage: MemoryImage(_profileImageBytes!),
                  )
                : (_currentImageUrl?.isNotEmpty ?? false)
                ? CircleAvatar(
                    radius: 52,
                    backgroundImage: NetworkImage(_currentImageUrl!),
                  )
                : const CircleAvatar(
                    radius: 52,
                    child: Icon(Icons.person, size: 42),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Profile Picture',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Capture or upload a picture under 50KB.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _pickProfileImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Capture / Upload'),
              ),
              if (_profileImageBytes != null ||
                  (_currentImageUrl?.isNotEmpty ?? false))
                OutlinedButton(
                  onPressed: _saving ? null : _removeSelectedImage,
                  child: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
