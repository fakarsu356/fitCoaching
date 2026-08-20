import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'auth_scaffold.dart';

/// Kayıt formlarındaki e-posta doğrulama adımı: koda kadar olan her şeyi
/// kendi içinde yönetir, dışarıya sadece girilen kodu verir.
///
/// Öğrenci ve koç kayıtları aynı akışı kullanıyor; ikisinde de tekrar
/// yazılmasın diye tek bileşen.
class EmailVerificationField extends StatefulWidget {
  const EmailVerificationField({
    super.key,
    required this.controller,
    required this.emailOf,
    this.enabled = true,
  });

  /// Kullanıcının girdiği 6 haneli kod.
  final TextEditingController controller;

  /// Kodun gönderileceği adresi form alanından okur. Doğrudan denetleyici
  /// almak yerine geri çağırım: adres formun kendi alanında duruyor ve kod
  /// gönderilirken güncel değeri gerekiyor.
  final String Function() emailOf;

  final bool enabled;

  @override
  State<EmailVerificationField> createState() => _EmailVerificationFieldState();
}

class _EmailVerificationFieldState extends State<EmailVerificationField> {
  /// Sunucudaki kod 5 dakika geçerli; tekrar gönderme bundan bağımsız olarak
  /// 60 saniyede bir açılıyor ki kullanıcı üst üste mail istemesin.
  static const int _resendSeconds = 60;

  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;

  /// Kodun gönderildiği adres. Kullanıcı e-postayı sonradan değiştirirse
  /// uyarı gösterilir: kod eski adrese gitmiştir.
  String? _sentTo;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final email = widget.emailOf().trim();
    final emailError = Validators.email(email);
    if (emailError != null) {
      showAppSnack(context, 'Önce geçerli bir e-posta gir', isError: true);
      return;
    }

    setState(() => _sending = true);
    final result = await context.read<AppServices>().auth.sendVerificationCode(
      email,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!result.ok) {
      showAppSnack(context, result.errorMessage, isError: true);
      return;
    }

    setState(() => _sentTo = email);
    _startCountdown();
    showAppSnack(context, 'Doğrulama kodu $email adresine gönderildi');
  }

  bool get _canSend =>
      widget.enabled && !_sending && _secondsLeft == 0;

  String get _buttonLabel {
    if (_secondsLeft > 0) return 'Tekrar gönder ($_secondsLeft)';
    return _sentTo == null ? 'Kod gönder' : 'Tekrar gönder';
  }

  /// Kod gönderildikten sonra adres değiştiyse kullanıcı yanlış kodu
  /// bekliyordur; sessizce başarısız olmaktansa söylenir.
  bool get _emailChanged =>
      _sentTo != null && _sentTo != widget.emailOf().trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'E-posta doğrulama',
          hint: _sentTo == null
              ? 'Adresine 6 haneli bir kod göndereceğiz.'
              : '$_sentTo adresine gönderilen kodu gir. Kod 5 dakika geçerli.',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '123456',
                    counterText: '',
                  ),
                  validator: _validateCode,
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                flex: 4,
                child: SizedBox(
                  // Buton yüksekliği alanla aynı olsun diye sabitlendi.
                  height: AppSizes.controlHeight,
                  child: OutlinedButton(
                    // Tema `minimumSize: Size.fromHeight(48)` veriyor, yani en
                    // küçük genişlik sonsuz. Satır içinde bu ölçü yerleşimi
                    // patlatıyor; burada genişlik serbest bırakılıyor.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.controlHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _canSend ? _send : null,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _buttonLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_emailChanged) ...[
          const SizedBox(height: AppSizes.gapSmall),
          AuthErrorBanner(
            message:
                'Kod $_sentTo adresine gönderildi ama e-postayı değiştirdin. '
                'Yeni adrese kod göndermek için "Tekrar gönder"e bas.',
          ),
        ],
      ],
    );
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return _sentTo == null
          ? 'Önce "Kod gönder"e bas, sonra gelen kodu yaz'
          : 'Doğrulama kodu gerekli';
    }
    if (code.length != 6) return 'Kod 6 haneli olmalı';
    return null;
  }
}
