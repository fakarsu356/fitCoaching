import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/relation.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Kilo ve yağ oranını güncelleme.
///
/// Yaş, boy ve cinsiyet burada yok: bunlar kayıt sırasında belirleniyor ve
/// değişmesi beklenmiyor, uç da onları güncellemiyor. Kaydedilirse güncel
/// öğrenci kaydı döner, çağıran ekran ayrıca istek atmaz.
Future<Student?> showEditStudentMetricsSheet(
  BuildContext context,
  Student student,
) {
  return showModalBottomSheet<Student>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => _EditStudentMetricsSheet(student: student),
  );
}

class _EditStudentMetricsSheet extends StatefulWidget {
  const _EditStudentMetricsSheet({required this.student});

  final Student student;

  @override
  State<_EditStudentMetricsSheet> createState() =>
      _EditStudentMetricsSheetState();
}

class _EditStudentMetricsSheetState extends State<_EditStudentMetricsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _fat;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: formatNumber(widget.student.bodyWeight),
    );
    _fat = TextEditingController(
      text: formatNumber(widget.student.fatPercentage),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    super.dispose();
  }

  /// Virgül de nokta da kabul edilir ("82,5" = "82.5").
  double? _parse(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final weight = _parse(_weight);
    final fat = _parse(_fat);
    if (weight == null || fat == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context
        .read<AppServices>()
        .profiles
        .updateStudentProfile(bodyWeight: weight, fatPercentage: fat);

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
      return;
    }
    // Uç güncel kaydı döndürmediyse elimizdeki değerleri yazarak devam edilir;
    // kayıt sunucuda zaten güncellendi.
    final updated =
        result.data ??
        Student(
          userId: widget.student.userId,
          age: widget.student.age,
          bodyWeight: weight,
          fatPercentage: fat,
          bodyHeight: widget.student.bodyHeight,
          username: widget.student.username,
          email: widget.student.email,
          gender: widget.student.gender,
        );
    Navigator.of(context).pop(updated);
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
              'Ölçülerini güncelle',
              subtitle: 'Koçun gelişimini buradan takip ediyor.',
            ),
            const SizedBox(height: AppSizes.gapSmall),
            LabeledField(
              label: 'Kilon',
              child: TextFormField(
                controller: _weight,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: weightInputFormatters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'örn. 78,5',
                  suffixText: 'kg',
                ),
                validator: Validators.bodyWeight,
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Yağ oranın',
              child: TextFormField(
                controller: _fat,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: weightInputFormatters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: _busy ? null : (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'örn. 18',
                  suffixText: '%',
                ),
                // Yağ oranı burada zorunlu: ekranda zaten bir değer duruyor,
                // boş bırakılması bilgiyi silmek anlamına gelirdi.
                validator: (value) => Validators.doubleInRange(
                  value,
                  min: Validators.minFat,
                  max: Validators.maxFat,
                  label: 'Yağ oranı',
                ),
              ),
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
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
