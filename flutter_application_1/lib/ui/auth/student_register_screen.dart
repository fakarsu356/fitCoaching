import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'auth_scaffold.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _fat = TextEditingController();

  String? _gender;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    _fat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    if (_gender == null) {
      setState(() => _error = 'Cinsiyet seçmelisin');
      return;
    }
    if (!formOk) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().auth.registerStudent(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      passwordConfirm: _passwordConfirm.text,
      age: Validators.toInt(_age.text),
      bodyFatPercentage: _fat.text.trim().isEmpty
          ? null
          : Validators.toDouble(_fat.text),
      bodyWeight: Validators.toDouble(_weight.text),
      bodyHeight: Validators.toDouble(_height.text),
      gender: _gender!,
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
      return;
    }

    // Backend kayıtta token dönmüyor; kullanıcı giriş ekranına dönüp giriş yapar.
    Navigator.of(context).popUntil((route) => route.isFirst);
    showAppSnack(context, 'Kaydın tamamlandı, şimdi giriş yapabilirsin');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Öğrenci kaydı',
      subtitle: 'Vücut bilgilerin koçunun program yazmasında kullanılır.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Ad soyad',
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Adın'),
                  validator: (value) =>
                      Validators.required(value, label: 'Ad soyad'),
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
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Yaş',
                      child: TextFormField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: '25'),
                        validator: Validators.age,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.gapSmall + 4),
                  Expanded(
                    child: LabeledField(
                      label: 'Yağ oranı (%)',
                      hint: 'Bilmiyorsan boş bırakabilirsin.',
                      child: TextFormField(
                        controller: _fat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'İsteğe bağlı',
                        ),
                        validator: Validators.fatPercentageOptional,
                      ),
                    ),
                  ),
                ],
              ),
              formGap,
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Kilo (kg)',
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: '78'),
                        validator: Validators.bodyWeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.gapSmall + 4),
                  Expanded(
                    child: LabeledField(
                      label: 'Boy (cm)',
                      child: TextFormField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(hintText: '180'),
                        validator: Validators.bodyHeight,
                      ),
                    ),
                  ),
                ],
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
