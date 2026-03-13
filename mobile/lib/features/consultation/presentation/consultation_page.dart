import 'dart:async';

import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/consultation/data/consultation_repository.dart';
import 'package:optima_healthcare_mobile/features/consultation/data/deepgram_streaming_service.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_list_item.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real-time AI consultation transcription for doctors.
/// Doctor selects a patient, then uses Start/Stop Audio to capture speech.
/// Transcribed text appears in the text box via AssemblyAI streaming.
class ConsultationPage extends StatefulWidget {
  const ConsultationPage({super.key});

  @override
  State<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  static const _apiKey = 'eb834229897f7beec1e5e73af4a7054aee0876a6';

  final _patientRepo = PatientRepository();
  final _consultationRepo = ConsultationRepository();
  late DeepgramStreamingService _streamingService;

  List<PatientListItemModel> _patients = [];
  PatientListItemModel? _selectedPatient;
  bool _loadingPatients = true;
  String? _error;

  final _transcriptController = TextEditingController();
  String _partialText = '';
  bool _isRecording = false;
  String? _streamError;
  DeepgramLanguage _selectedLanguage = DeepgramLanguage.en;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _streamingService = DeepgramStreamingService(
      apiKey: _apiKey,
      onTranscript: _handleTranscript,
      language: _selectedLanguage,
    );
    _loadPatients();
  }

  void _updateServiceLanguage() {
    _streamingService.dispose();
    _streamingService = DeepgramStreamingService(
      apiKey: _apiKey,
      onTranscript: _handleTranscript,
      language: _selectedLanguage,
    );
  }

  @override
  void dispose() {
    _streamingService.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loadingPatients = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    setState(() {
      _loadingPatients = true;
      _error = null;
    });

    try {
      final list = await _patientRepo.listPatients(accessToken: token);
      setState(() {
        _patients = list;
        _loadingPatients = false;
        if (list.isNotEmpty && _selectedPatient == null) {
          _selectedPatient = list.first;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingPatients = false;
      });
    }
  }

  void _onStreamError(String error) {
    if (!mounted) return;
    setState(() => _streamError = error);
  }

  String _lastFinalTranscript = '';

  void _handleTranscript(String text, bool isFinal) {
    if (!mounted) return;
    setState(() {
      _streamError = null;
      if (isFinal) {
        _partialText = '';
        // Append only new content (Deepgram sends cumulative: "Hi" -> "Hi how" -> "Hi how are you")
        if (text.startsWith(_lastFinalTranscript)) {
          final newPart = text.substring(_lastFinalTranscript.length).trim();
          if (newPart.isNotEmpty) {
            final current = _transcriptController.text;
            _transcriptController.text = current.isEmpty ? newPart : '$current $newPart';
          }
        } else {
          _transcriptController.text = _transcriptController.text.isEmpty ? text : '${_transcriptController.text} $text';
        }
        _lastFinalTranscript = text;
      } else {
        _partialText = text;
      }
    });
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for transcription.'),
          ),
        );
      }
      return;
    }

    _updateServiceLanguage();
    setState(() {
      _streamError = null;
      _isRecording = true;
      _lastFinalTranscript = '';
    });

    try {
      await _streamingService.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _streamError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    await _streamingService.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        if (_partialText.isNotEmpty) {
          final current = _transcriptController.text;
          _transcriptController.text = current.isEmpty ? _partialText : '$current $_partialText';
          _partialText = '';
        }
      });
    }
  }

  Future<void> _saveToDatabase() async {
    final token = AuthSession.accessToken;
    final patient = _selectedPatient;
    final transcript = _transcriptController.text.trim();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please login again.')),
      );
      return;
    }
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient.')),
      );
      return;
    }
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript to save. Record audio first.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _consultationRepo.saveConsultationNotes(
        accessToken: token,
        patientDataId: patient.patientDataId,
        transcript: transcript,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation saved. Complaint, symptoms, and medical history recorded.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingPatients ? null : _loadPatients,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Patient selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Patient',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingPatients)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red))
                else
                  DropdownButtonFormField<PatientListItemModel>(
                    value: _selectedPatient,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Select a patient'),
                    items: _patients
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.firstName} ${p.lastName} (${p.email})'),
                            ))
                        .toList(),
                    onChanged: _isRecording
                        ? null
                        : (p) => setState(() => _selectedPatient = p),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Transcription Language',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DeepgramLanguage>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: DeepgramLanguage.values
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang.displayName),
                          ))
                      .toList(),
                  onChanged: _isRecording
                      ? null
                      : (lang) => setState(() {
                            _selectedLanguage = lang ?? DeepgramLanguage.en;
                            _updateServiceLanguage();
                          }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Transcript area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Transcription',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.surfaceContainerLow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SelectableText(
                                    _transcriptController.text,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  if (_partialText.isNotEmpty)
                                    SelectableText(
                                      _partialText,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_streamError != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _streamError!,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Start / Stop / Save buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isRecording
                              ? null
                              : (_selectedPatient == null ? null : _requestPermissionAndStart),
                          icon: Icon(_isRecording ? Icons.mic : Icons.mic_none),
                          label: Text(_isRecording ? 'Recording…' : 'Start Audio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isRecording ? _stopRecording : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Audio'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || _isRecording || _transcriptController.text.trim().isEmpty
                          ? null
                          : _saveToDatabase,
                      icon: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving…' : 'Save to Database'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
