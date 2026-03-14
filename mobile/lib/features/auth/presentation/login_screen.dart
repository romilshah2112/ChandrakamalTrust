import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/data/auth_repository.dart';
import 'package:optima_healthcare_mobile/features/auth/data/user_profile_repository.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/auth/models/signup_request.dart';
import 'package:optima_healthcare_mobile/features/auth/models/user_role_option.dart';
import 'package:optima_healthcare_mobile/shared/widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  final _authRepository = AuthRepository();
  final _userProfileRepository = UserProfileRepository();

  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _loadingRoles = false;
  String? _error;
  String? _message;

  List<UserRoleOptionModel> _allowedRoles = const [];
  int? _selectedRoleId;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });

    try {
      final loginResult = await _authRepository.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      String? firstName;
      String? lastName;
      try {
        final profile = await _userProfileRepository.getMyProfile(
          accessToken: loginResult.accessToken,
        );
        firstName = profile.firstName;
        lastName = profile.lastName;
      } catch (_) {
        // Keep login resilient even if profile loading fails.
      }

      AuthSession.set(
        appUserIdValue: loginResult.appUserId,
        usernameValue: loginResult.username,
        roleValue: loginResult.role,
        accessTokenValue: loginResult.accessToken,
        firstNameValue: firstName,
        lastNameValue: lastName,
      );

      if (!mounted) {
        return;
      }

      final dashboardRoute = AppRouter.routeForRole(loginResult.role);
      Navigator.of(context).pushReplacementNamed(dashboardRoute);
    } on AuthException catch (ex) {
      setState(() {
        _error = ex.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to connect to server. Check API base URL.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) {
      return;
    }
    if (_selectedRoleId == null) {
      setState(() {
        _error = 'Please select a role.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });

    try {
      await _authRepository.signUp(
        SignUpRequestModel(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          emailAddress: _emailController.text.trim(),
          password: _signUpPasswordController.text,
          userRoleId: _selectedRoleId!,
        ),
      );

      setState(() {
        _isSignUpMode = false;
        _message = 'Sign up successful. You can login now.';
        _usernameController.text = _mobileController.text.trim();
        _passwordController.clear();
      });
    } on AuthException catch (ex) {
      setState(() {
        _error = ex.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to connect to server. Check API base URL.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllowedRoles() async {
    setState(() {
      _loadingRoles = true;
      _error = null;
      _message = null;
    });

    try {
      final roles = await _authRepository.getAllowedRoles();
      setState(() {
        _allowedRoles = roles;
        _selectedRoleId = roles.isNotEmpty ? roles.first.userRoleId : null;
      });
    } on AuthException catch (ex) {
      setState(() {
        _error = ex.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load roles from server.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoles = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _error = null;
      _message = null;
    });

    if (_isSignUpMode && _allowedRoles.isEmpty) {
      _loadAllowedRoles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _isSignUpMode ? _buildSignUpForm(context) : _buildLoginForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandLogo(height: 60, showFallbackText: true)),
          const SizedBox(height: 10),
          Text(
            'Padam Heart Care Centre Login',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Mobile Number or Email',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter username' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 4),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_message!, style: const TextStyle(color: Colors.green)),
            ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Login'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            child: const Text('Create new account'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(BuildContext context) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandLogo(height: 54)),
          const SizedBox(height: 8),
          Text(
            'Create AppUser',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter first name' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter last name' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter mobile number';
              }
              if (int.tryParse(value.trim()) == null) {
                return 'Mobile must be numeric';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter email' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            validator: (value) => value == null || value.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 10),
          if (_loadingRoles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedRoleId,
              items: _allowedRoles
                  .map((role) => DropdownMenuItem<int>(
                        value: role.userRoleId,
                        child: Text(role.roleName),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRoleId = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null ? 'Select role' : null,
            ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_message!, style: const TextStyle(color: Colors.green)),
            ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isLoading || _loadingRoles ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign Up'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }
}
