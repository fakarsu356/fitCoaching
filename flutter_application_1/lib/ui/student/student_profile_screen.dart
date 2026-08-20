import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/tracking.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../../state/auth_controller.dart';
import '../widgets/common.dart';

/// config.MaxFileSize ile aynı: 5 MB. Sunucuya gitmeden önce burada uyarılır.
const int _maxFileSize = 5 * 1024 * 1024;

/// config.AllowedTypes ile aynı küme. Android MIME, masaüstü uzantı ile
/// filtrelediği için ikisi de veriliyor.
const List<XTypeGroup> _documentTypes = [
  XTypeGroup(
    label: 'Belge',
    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    uniformTypeIdentifiers: ['com.adobe.pdf', 'public.jpeg', 'public.png'],
  ),
];

/// Öğrencinin kendi profili: yüklediği belgeler, kontrol fotoğrafları ve hesap.
///
/// Belge listesi ucu öğrenci rolünde `student_id` istemiyor, kendi kayıtlarını
/// döndürüyor; koçun gördüğü liste de aynı uçtan besleniyor.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  List<DocumentItem>? _documents;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  /// İndirilen görseller liste yenilenmedikçe tekrar çekilmesin diye belge
  /// kimliğine göre saklanıyor; indirilemeyen için null yazılıyor.
  final Map<int, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await context.read<AppServices>().documents.getList();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _documents = result.data ?? const <DocumentItem>[];
        // Liste yenilendiğinde silinmiş belgelerin baytları bellekte kalmasın.
        _imageCache.clear();
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<Uint8List?> _imageBytes(int fileId) async {
    if (_imageCache.containsKey(fileId)) return _imageCache[fileId];
    final result = await context.read<AppServices>().documents.download(fileId);
    final data = result.data;
    final bytes = result.ok && data != null && data.isNotEmpty
        ? Uint8List.fromList(data)
        : null;
    _imageCache[fileId] = bytes;
    return bytes;
  }

  Future<void> _openImage(DocumentItem document) async {
    final bytes = await _imageBytes(document.id);
    if (!mounted) return;
    if (bytes == null) {
      showAppSnack(context, 'Resim açılamadı');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
              child: Text(
                document.docName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
          ],
        ),
      ),
    );
  }

  /// Önce tür seçtiriliyor: sunucu `type` alanını zorunlu tutuyor ve tahlil
  /// ile gelişim fotoğrafını ayrı saklıyor.
  Future<void> _upload() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSizes.pagePadding),
              child: SectionTitle(
                'Ne yüklüyorsun?',
                subtitle: 'Koçun bunu profilinde görecek.',
              ),
            ),
            for (final entry in DocumentType.studentUploadable.entries)
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(entry.value),
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
            const SizedBox(height: AppSizes.gapSmall),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    final selected = await openFiles(acceptedTypeGroups: _documentTypes);
    if (selected.isEmpty || !mounted) return;

    final files = <UploadFile>[];
    for (final file in selected) {
      if (await file.length() > _maxFileSize) {
        if (!mounted) return;
        showAppSnack(context, '${file.name} 5 MB sınırını aşıyor');
        continue;
      }
      files.add(UploadFile(name: file.name, path: file.path));
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    final result = await context.read<AppServices>().documents.upload(
      files: files,
      type: type,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    showAppSnack(
      context,
      result.ok ? 'Yüklendi' : (result.message ?? 'Yükleme başarısız'),
    );
    if (result.ok) await _load();
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthController>();
    final confirmed = await confirmDialog(
      context,
      title: 'Çıkış yap',
      message: 'Oturumun kapatılacak. Devam edilsin mi?',
      confirmLabel: 'Çıkış yap',
      destructive: true,
    );
    if (confirmed) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final documents = _documents ?? const <DocumentItem>[];
    final images = documents.where((document) => document.isImage).toList();
    final files = documents.where((document) => !document.isImage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_uploading ? 'Yükleniyor' : 'Belge yükle'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.pagePadding,
            AppSizes.pagePadding,
            AppSizes.pagePadding + 72,
          ),
          children: [
            const SectionTitle(
              'Belgeler',
              subtitle: 'Tahlil ve raporların.',
            ),
            if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else if (_loading)
              const _ProfileSkeleton()
            else if (files.isEmpty)
              const _EmptyCard(
                icon: Icons.description_outlined,
                message: 'Henüz belge yüklemedin.',
              )
            else
              for (final document in files) ...[
                _DocumentTile(document: document),
                const SizedBox(height: AppSizes.gapSmall),
              ],
            const SizedBox(height: AppSizes.gapLarge),
            const SectionTitle(
              'Resimler',
              subtitle: 'Gelişim ve öğün fotoğrafların — koçun kontrolü için.',
            ),
            if (_error != null)
              const SizedBox.shrink()
            else if (_loading)
              const _ProfileSkeleton()
            else if (images.isEmpty)
              const _EmptyCard(
                icon: Icons.image_outlined,
                message: 'Henüz resim yüklemedin.',
              )
            else
              _ImageGrid(
                images: images,
                loader: _imageBytes,
                onOpen: _openImage,
              ),
            const SizedBox(height: AppSizes.gapLarge),
            const SectionTitle('Hesap'),
            AppCard(
              child: InfoRow(
                'Rol',
                'Öğrenci',
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            OutlinedButton.icon(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Çıkış yap'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resim dışı belge satırı; liste ucu içerik göndermediği için önizleme yok.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(
              document.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.cardPaddingCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.docName.trim().isEmpty
                      ? 'Belge #${document.id}'
                      : document.docName.trim(),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${document.typeLabel} · ${AppDate.short(document.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Üçlü ızgara; dokununca tam boy açılıyor.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.images,
    required this.loader,
    required this.onOpen,
  });

  final List<DocumentItem> images;

  /// Bayt indirme ekranın state'inde: önbellek yeniden çizimlerde korunuyor.
  final Future<Uint8List?> Function(int fileId) loader;
  final void Function(DocumentItem document) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.gapSmall,
        mainAxisSpacing: AppSizes.gapSmall,
      ),
      itemBuilder: (context, index) {
        final document = images[index];
        return _ImageTile(
          document: document,
          loader: loader,
          onOpen: () => onOpen(document),
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.document,
    required this.loader,
    required this.onOpen,
  });

  final DocumentItem document;
  final Future<Uint8List?> Function(int fileId) loader;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: FutureBuilder<Uint8List?>(
            future: loader(document.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Skeleton(
                  width: double.infinity,
                  height: double.infinity,
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                // İndirilemeyen görsel ızgarada boşluk bırakmasın diye yerine
                // bir simge konuyor.
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                );
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 140, height: 14),
          SizedBox(height: AppSizes.gapSmall),
          Skeleton(width: double.infinity, height: 12),
          SizedBox(height: 6),
          Skeleton(width: 180, height: 12),
        ],
      ),
    );
  }
}
