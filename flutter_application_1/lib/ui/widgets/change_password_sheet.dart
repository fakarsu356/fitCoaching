import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/services.dart';
import '../../state/auth_controller.dart';
import 'common.dart';

/// Şifre değiştirme sayfası. Koç ve öğrenci profillerinin ikisi de bunu açıyor;
/// uç (`/profile/resetPassword`) role bakmadığı için tek ekran yetiyor.
///
/// Şifre değiştikten sonra oturum kapatılmıyor: elde duran access token JWT
/// olduğu için sunucu tarafında geçerliliğini koruyor, kullanıcıyı zorla dışarı
/// atmak kazanç sağlamıyor.
Future<bool> showChangePasswordSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => const _ChangePasswordSheet(),
  );
  return changed ?? false;
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Kullanıcı id'si access token'ın içinden geliyor; uç gövdede istiyor.
    final userId = context.read<AuthController>().userId;
    if (userId == null) {
      setState(() => _error = 'Oturum bilgisi okunamadı, yeniden giriş yap');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().profiles.resetPassword(
      userId: userId,
      oldPassword: _current.text,
      newPassword: _next.text,
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.pagePadding,
        right: AppSizes.pagePadding,
        top: AppSizes.pagePadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.pagePadding,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              'Şifre değiştir',
              subtitle: 'Yeni şifren bir sonraki girişinde geçerli olacak.',
            ),
            const SizedBox(height: AppSizes.gapSmall),
            _PasswordField(
              label: 'Mevcut şifren',
              hint: 'şu an kullandığın şifre',
              controller: _current,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.required(value, label: 'Mevcut şifre'),
            ),
            const SizedBox(height: AppSizes.gap),
            _PasswordField(
              label: 'Yeni şifren',
              hint: 'en az 6 karakter',
              controller: _next,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final invalid = Validators.password(value);
                if (invalid != null) return invalid;
                if (value == _current.text) {
                  return 'Yeni şifre eskisiyle aynı olamaz';
                }
                return null;
              },
              // Kurallar hataya düşmeden önce de görünsün.
              helper:
                  'En az 6 karakter, 1 küçük harf, 1 rakam ve '
                  r'. ! @ # $ % ^ & * içinden 1 özel karakter.',
            ),
            const SizedBox(height: AppSizes.gap),
            _PasswordField(
              label: 'Yeni şifren (tekrar)',
              hint: 'aynısını bir daha yaz',
              controller: _confirm,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: _busy ? null : (_) => _submit(),
              validator: (value) =>
                  Validators.passwordConfirm(value, _next.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.gapSmall),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSizes.gap),
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
                  : const Text('Şifreyi değiştir'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Göz düğmesiyle gizlenip açılabilen şifre alanı.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.helper,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 3,
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Göster' : 'Gizle',
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
    );
  }
}
