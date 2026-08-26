import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'common.dart';

/// Belge önizlemesi. Resimler yakınlaştırılabilir şekilde açılır; PDF ve diğer
/// türlerde uygulama içi görüntüleyici olmadığı için bunu açıkça söyleyen bir
/// kart gösterilir.
///
/// Aynı görünüm koç profili, öğrenci profili ve öğrenci detay ekranlarında
/// kullanılsın diye tek yerde duruyor.
Future<void> showDocumentPreview(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Uint8List? bytes,
  required bool isImage,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (isImage && bytes != null && bytes.isNotEmpty)
            Flexible(child: InteractiveViewer(child: Image.memory(bytes)))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                0,
                AppSizes.pagePadding,
                AppSizes.pagePadding,
              ),
              child: Text(
                isImage
                    ? 'Dosya içeriği alınamadı.'
                    : 'Bu belge uygulama içinde önizlenemiyor; yalnızca '
                          'resimler açılabiliyor.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Belge kutucuklarının sol tarafındaki kare ikon/küçük resim.
class DocumentThumbnail extends StatelessWidget {
  const DocumentThumbnail({
    super.key,
    required this.icon,
    this.bytes,
  });

  final IconData icon;

  /// Varsa küçük resim olarak gösterilir; yoksa [icon] çizilir.
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final preview = bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: Container(
        width: AppSizes.avatar,
        height: AppSizes.avatar,
        color: AppColors.surfaceMuted,
        child: preview != null && preview.isNotEmpty
            ? Image.memory(preview, fit: BoxFit.cover)
            : Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

/// İçeriği sunucudan indirilip önbelleğe alınan belgeler için ortak yükleyici.
///
/// Aynı belge ekranda hem küçük resim hem önizleme olarak istendiğinde iki kez
/// indirilmesin diye sonuç (başarısızlık dahil) saklanıyor.
class DocumentBytesCache {
  DocumentBytesCache(this._download);

  final Future<List<int>?> Function(int fileId) _download;
  final Map<int, Uint8List?> _cache = {};

  Future<Uint8List?> bytesOf(int fileId) async {
    if (_cache.containsKey(fileId)) return _cache[fileId];
    final data = await _download(fileId);
    final bytes = (data == null || data.isEmpty)
        ? null
        : Uint8List.fromList(data);
    _cache[fileId] = bytes;
    return bytes;
  }
}

/// Belge açılamadığında gösterilen ortak uyarı.
void showDocumentError(BuildContext context) {
  showAppSnack(context, 'Belge açılamadı');
}
