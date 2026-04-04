import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optima_healthcare_mobile/features/auth/data/user_profile_repository.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/auth/models/update_user_profile_request.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const int _maxImageBytes = 100 * 1024;

  final _repo = UserProfileRepository();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;
  Uint8List? _profileImageBytes;
  String? _profileImageFileName;
  String? _profileImageContentType;
  String? _currentProfileImage;
  String? _imageLoadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    try {
      final profile = await _repo.getMyProfile(accessToken: token);
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _mobile.text = '${profile.mobileNumber}';
      _email.text = profile.emailAddress;
      _currentProfileImage = _normalizeRemoteImageUrl(profile.profileImage);
      _imageLoadError = null;
      AuthSession.updateProfileName(
        firstNameValue: profile.firstName,
        lastNameValue: profile.lastName,
      );
      setState(() {
        _loading = false;
      });
    } catch (ex) {
      setState(() {
        _loading = false;
        _error = ex.toString();
      });
    }
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
        _imageLoadError = null;
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

  void _removeProfileImage() {
    setState(() {
      _profileImageBytes = null;
      _profileImageFileName = null;
      _profileImageContentType = null;
      _currentProfileImage = null;
      _imageLoadError = null;
    });
  }

  String? _normalizeRemoteImageUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    if (uri.host.isEmpty) {
      return null;
    }

    return trimmed;
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
      await _repo.updateMyProfile(
        accessToken: token,
        request: UpdateUserProfileRequestModel(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          mobileNumber: _mobile.text.trim(),
          emailAddress: _email.text.trim(),
          profileImage: _profileImageBytes == null
              ? _currentProfileImage
              : null,
          imageBase64: _profileImageBytes == null
              ? null
              : base64Encode(_profileImageBytes!),
          imageFileName: _profileImageFileName,
          imageContentType: _profileImageContentType,
          newPassword: _newPassword.text.trim().isEmpty
              ? null
              : _newPassword.text,
        ),
      );

      setState(() {
        _message = 'Profile updated successfully.';
        _newPassword.clear();
        if (_profileImageBytes != null) {
          _currentProfileImage = null;
        }
      });
      await _load();
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
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _imageSection(),
                    _field(_firstName, 'First Name'),
                    _field(_lastName, 'Last Name'),
                    _field(_mobile, 'Mobile Number', numeric: true),
                    _field(_email, 'Email'),
                    _field(
                      _newPassword,
                      'New Password (optional)',
                      required: false,
                    ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Profile'),
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
                    radius: 56,
                    backgroundImage: MemoryImage(_profileImageBytes!),
                  )
                : (_currentProfileImage != null)
                ? CircleAvatar(
                    radius: 56,
                    child: ClipOval(
                      child: Image.network(
                        _currentProfileImage!,
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _imageLoadError =
                                  'Profile image could not be loaded from the saved URL.';
                            });
                          });
                          return const Icon(Icons.person, size: 44);
                        },
                      ),
                    ),
                  )
                : const CircleAvatar(
                    radius: 56,
                    child: Icon(Icons.person, size: 44),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Profile Picture',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Capture or upload a profile picture under 100KB.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (_imageLoadError != null) ...[
            const SizedBox(height: 8),
            Text(
              _imageLoadError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
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
              if (_profileImageBytes != null || _currentProfileImage != null)
                OutlinedButton(
                  onPressed: _saving ? null : _removeProfileImage,
                  child: const Text('Remove'),
                ),
            ],
          ),
        ],
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
}
