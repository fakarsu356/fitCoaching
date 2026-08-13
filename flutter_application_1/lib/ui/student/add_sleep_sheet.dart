import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Gece uykusunu kaydetme. Kaydedilirse `true` döner.
Future<bool> showAddSleepSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => const _AddSleepSheet(),
  );
  return saved ?? false;
}

class _AddSleepSheet extends StatefulWidget {
  const _AddSleepSheet();

  @override
  State<_AddSleepSheet> createState() => _AddSleepSheetState();
}

class _AddSleepSheetState extends State<_AddSleepSheet> {
  /// Varsayılan: dün 23:00 - bugün 07:00. Kullanıcı iki saati de değiştirir.
  late DateTime _bedTime;
  late DateTime _wakeTime;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _bedTime = today.subtract(const Duration(hours: 1)); // dün 23:00
    _wakeTime = today.add(const Duration(hours: 7)); // bugün 07:00
  }

  Future<void> _pick({required bool isBedTime}) async {
    final initial = isBedTime ? _bedTime : _wakeTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isBedTime) {
        _bedTime = value;
      } else {
        _wakeTime = value;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_bedTime.isBefore(_wakeTime)) {
      setState(() => _error = 'Yatış saati uyanma saatinden önce olmalı');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().sleep.addSleep(
      bedTime: _bedTime,
      wakeTime: _wakeTime,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            'Uyku ekle',
            subtitle: 'Gece ne zaman yattığını ve uyandığını kaydet.',
          ),
          const SizedBox(height: AppSizes.gapSmall),
          _TimeField(
            label: 'Yattığın saat',
            value: _bedTime,
            icon: Icons.bedtime_outlined,
            onTap: _busy ? null : () => _pick(isBedTime: true),
          ),
          const SizedBox(height: AppSizes.gap),
          _TimeField(
            label: 'Uyandığın saat',
            value: _wakeTime,
            icon: Icons.wb_sunny_outlined,
            onTap: _busy ? null : () => _pick(isBedTime: false),
          ),
          const SizedBox(height: AppSizes.gap),
          // Seçime göre hesaplanan süre; yanlış saat seçildiyse hemen görülür.
          Text(
            'Toplam uyku: ${AppDate.duration(_bedTime, _wakeTime)}',
            style: Theme.of(context).textTheme.bodySmall,
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
                : const Text('Uykuyu kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Tıklanınca tarih + saat seçtiren alan görünümü.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final DateTime value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: Container(
          height: AppSizes.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                AppDate.long(value),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
