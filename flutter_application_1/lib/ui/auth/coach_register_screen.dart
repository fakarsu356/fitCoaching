import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'auth_scaffold.dart';
import 'email_verification_field.dart';

/// config.MaxFileSize ile aynı: 5 MB. Sunucuya gitmeden önce burada uyarılır.
const int _maxFileSize = 5 * 1024 * 1024;

/// config.AllowedTypes ile aynı küme. Android MIME, masaüstü uzantı ile filtrelediği
/// için ikisi de veriliyor.
const List<XTypeGroup> _documentTypes = [
  XTypeGroup(
    label: 'Belge',
    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    uniformTypeIdentifiers: ['com.adobe.pdf', 'public.jpeg', 'public.png'],
  ),
];

class CoachRegisterScreen extends StatefulWidget {
  const CoachRegisterScreen({super.key});

  @override
  State<CoachRegisterScreen> createState() => _CoachRegisterScreenState();
}

class _CoachRegisterScreenState extends State<CoachRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _maxStudents = TextEditingController();
  final _code = TextEditingController();

  String? _gender;
  String? _speciality;
  UploadFile? _cv;
  final List<UploadFile> _certificates = [];

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _maxStudents.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Dosya seçtirir; boyut kontrolünü burada yapar.
  Future<List<UploadFile>> _pickFiles({required bool multiple}) async {
    final List<XFile> selected;
    if (multiple) {
      selected = await openFiles(acceptedTypeGroups: _documentTypes);
    } else {
      final file = await openFile(acceptedTypeGroups: _documentTypes);
      selected = file == null ? const [] : [file];
    }

    final picked = <UploadFile>[];
    for (final file in selected) {
      if (await file.length() > _maxFileSize) {
        if (mounted) {
          setState(() => _error = '${file.name} 5 MB sınırını aşıyor');
        }
        continue;
      }
      picked.add(UploadFile(name: file.name, path: file.path));
    }
    return picked;
  }

  Future<void> _pickCv() async {
    final files = await _pickFiles(multiple: false);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _cv = files.first;
      _error = null;
    });
  }

  Future<void> _pickCertificates() async {
    final files = await _pickFiles(multiple: true);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _certificates.addAll(files);
      _error = null;
    });
  }

  /// Form dışındaki (dosya, segment) alanların kontrolü.
  String? _validateSelections() {
    if (_gender == null) return 'Cinsiyet seçmelisin';
    if (_speciality == null) return 'Uzmanlık alanı seçmelisin';
    if (_cv == null) return 'CV yüklemen zorunlu';
    if (_certificates.isEmpty) return 'En az bir sertifika yüklemen gerekiyor';
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    final selectionError = _validateSelections();
    if (selectionError != null) {
      setState(() => _error = selectionError);
      return;
    }
    if (!formOk) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().auth.registerCoach(
      username: _username.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      passwordConfirm: _passwordConfirm.text,
      maxStudents: Validators.toInt(_maxStudents.text),
      speciality: _speciality!,
      gender: _gender!,
      code: _code.text.trim(),
      cv: _cv!,
      certificates: _certificates,
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
    showAppSnack(context, 'Kaydın tamamlandı, şimdi giriş yapabilirsin');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Koç kaydı',
      subtitle: 'CV ve sertifikaların onay sürecinde kullanılır.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Kullanıcı adı',
                child: TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Adın'),
                  validator: (value) =>
                      Validators.required(value, label: 'Kullanıcı adı'),
                ),
              ),
              formGap,
              LabeledField(
                label: 'E-posta',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'ornek@mail.com',
                  ),
                  validator: Validators.email,
                ),
              ),
              formGap,
              EmailVerificationField(
                controller: _code,
                emailOf: () => _email.text,
                enabled: !_busy,
              ),
              formGap,
              LabeledField(
                label: 'Şifre',
                hint:
                    'En az 6 karakter; 1 küçük harf, 1 rakam ve 1 özel karakter '
                    r'(. ! @ # $ % ^ & *) içermeli.',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
              ),
              formGap,
              LabeledField(
                label: 'Şifre tekrar',
                child: TextFormField(
                  controller: _passwordConfirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.passwordConfirm(value, _password.text),
                ),
              ),
              formGapLarge,
              LabeledField(
                label: 'Cinsiyet',
                child: SegmentedChoice<String>(
                  options: Gender.labels,
                  value: _gender,
                  onChanged: (value) => setState(() {
                    _gender = value;
                    _error = null;
                  }),
                ),
              ),
              formGap,
              LabeledField(
                label: 'Uzmanlık alanı',
                child: SegmentedChoice<String>(
                  options: {for (final item in Speciality.all) item: item},
                  value: _speciality,
                  onChanged: (value) => setState(() {
                    _speciality = value;
                    _error = null;
                  }),
                ),
              ),
              formGap,
              LabeledField(
                label: 'Öğrenci kontenjanı',
                hint: 'Aynı anda çalışmak istediğin öğrenci sayısı (1-19).',
                child: TextFormField(
                  controller: _maxStudents,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: '5'),
                  validator: Validators.maxStudentCount,
                ),
              ),
              formGapLarge,
              _FilePickerField(
                label: 'CV',
                hint: 'PDF, JPG veya PNG — en fazla 5 MB.',
                buttonLabel: _cv == null ? 'Dosya seç' : 'Değiştir',
                files: _cv == null ? const [] : [_cv!],
                onPick: _busy ? null : _pickCv,
                onRemove: (_) => setState(() => _cv = null),
              ),
              formGap,
              _FilePickerField(
                label: 'Sertifikalar',
                hint: 'Birden fazla dosya seçebilirsin.',
                buttonLabel: 'Dosya ekle',
                files: _certificates,
                onPick: _busy ? null : _pickCertificates,
                onRemove: (index) =>
                    setState(() => _certificates.removeAt(index)),
              ),
              if (_error != null) ...[
                formGap,
                AuthErrorBanner(message: _error!),
              ],
              formGapLarge,
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kaydı tamamla'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seçilen dosyaları listeleyen, ekleme/çıkarma yapılabilen alan.
class _FilePickerField extends StatelessWidget {
  const _FilePickerField({
    required this.label,
    required this.buttonLabel,
    required this.files,
    required this.onPick,
    required this.onRemove,
    this.hint,
  });

  final String label;
  final String? hint;
  final String buttonLabel;
  final List<UploadFile> files;
  final VoidCallback? onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      hint: hint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(buttonLabel),
          ),
          for (var i = 0; i < files.length; i++) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      files[i].name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () => onRemove(i),
                    tooltip: 'Kaldır',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
