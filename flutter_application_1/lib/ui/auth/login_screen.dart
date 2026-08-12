import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../state/auth_controller.dart';
import '../widgets/common.dart';
import 'auth_scaffold.dart';
import 'register_choice_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await context.read<AuthController>().login(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;
    // Giriş başarılıysa AppRoot durum değişikliğini dinleyip ekranı değiştirir,
    // burada ayrıca yönlendirme yapmaya gerek yok.
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      // Başlık yok: amblem ve altındaki tanıtım yazısı ekranın başlığı yerine
      // geçiyor, bu yüzden içerik yukarı yaslanıyor.
      showBack: false,
      alignTop: true,
      children: [
        const AppWordmark(),
        formGapLarge,
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'E-posta',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'ornek@mail.com',
                  ),
                  validator: Validators.email,
                ),
              ),
              formGap,
              LabeledField(
                label: 'Şifre',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    hintText: '••••••',
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
                  // Giriş ekranında şifre kuralı denetlenmez; eski hesaplar da
                  // giriş yapabilmeli.
                  validator: (value) => Validators.required(
                    value,
                    label: 'Şifre',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.gap),
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
                    : const Text('Giriş yap'),
              ),
              const SizedBox(height: AppSizes.gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabın yok mu?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterChoiceScreen(),
                            ),
                          ),
                    child: const Text('Kayıt ol'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
