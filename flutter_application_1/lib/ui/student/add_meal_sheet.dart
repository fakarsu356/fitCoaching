import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Bugüne öğün ekleme. Kaydedilirse `true` döner.
/// Tarih sunucuda damgalandığı için burada tarih alanı yok.
Future<bool> showAddMealSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => const _AddMealSheet(),
  );
  return saved ?? false;
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet();

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _oil = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _kcal.dispose();
    _protein.dispose();
    _oil.dispose();
    super.dispose();
  }

  /// Protein/yağ boş bırakılabilir; boşsa 0 gider.
  String? _optionalMacro(String? value, String label) {
    if (value == null || value.trim().isEmpty) return null;
    return Validators.doubleInRange(value, min: 0, max: 1000, label: label);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().meals.addMeal(
      mealName: _name.text.trim(),
      description: _description.text.trim(),
      kcal: Validators.toDouble(_kcal.text),
      protein: Validators.toDouble(_protein.text),
      oil: Validators.toDouble(_oil.text),
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
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

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
              'Öğün ekle',
              subtitle: 'Bugün yediğin bir öğünü kaydet.',
            ),
            const SizedBox(height: AppSizes.gapSmall),
            LabeledField(
              label: 'Öğün adı',
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Kahvaltı, ara öğün...',
                ),
                validator: (value) =>
                    Validators.required(value, label: 'Öğün adı'),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Kalori (kcal)',
              child: TextFormField(
                controller: _kcal,
                keyboardType: numberKeyboard,
                decoration: const InputDecoration(hintText: '650'),
                validator: (value) => Validators.doubleInRange(
                  value,
                  min: 1,
                  max: 10000,
                  label: 'Kalori',
                ),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Protein (g)',
                    hint: 'İsteğe bağlı.',
                    child: TextFormField(
                      controller: _protein,
                      keyboardType: numberKeyboard,
                      decoration: const InputDecoration(hintText: '0'),
                      validator: (value) => _optionalMacro(value, 'Protein'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: LabeledField(
                    label: 'Yağ (g)',
                    hint: 'İsteğe bağlı.',
                    child: TextFormField(
                      controller: _oil,
                      keyboardType: numberKeyboard,
                      decoration: const InputDecoration(hintText: '0'),
                      validator: (value) => _optionalMacro(value, 'Yağ'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Açıklama',
              hint: 'İstersen boş bırakabilirsin.',
              child: TextFormField(
                controller: _description,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Neler yedin?',
                  counterText: '',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.gap),
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
                  : const Text('Öğünü kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
