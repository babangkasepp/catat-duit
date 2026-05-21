import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../core/utils/formatters.dart';
import '../features/ocr/ocr_service.dart';
import '../features/ocr/receipt_parser.dart';

/// Hasil scan struk yang dikirim balik ke caller.
class ScanReceiptResult {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final String? imagePath;
  final bool autoSave;

  const ScanReceiptResult({
    this.amount,
    this.merchant,
    this.date,
    this.imagePath,
    this.autoSave = false,
  });
}

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  bool _busy = false;
  bool _didAutoPick = false;
  String? _imagePath;
  ReceiptParse? _parsed;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) Coba recover lost data (Android low-mem killed our activity)
      await _recoverLostData();
      if (!mounted || _didAutoPick) return;
      _didAutoPick = true;
      // 2) Kalau gak ada lost data, baru tanya source
      if (_imagePath == null) {
        await _pickSource();
      }
    });
  }

  Future<void> _recoverLostData() async {
    if (!Platform.isAndroid) return;
    try {
      final picker = ImagePickerPlatform.instance;
      if (picker is ImagePickerAndroid) {
        final response = await picker.getLostData();
        if (response.isEmpty) return;
        final files = response.files;
        if (files != null && files.isNotEmpty) {
          final file = files.first;
          if (!mounted) return;
          setState(() {
            _imagePath = file.path;
            _busy = true;
          });
          await _processImage(file.path);
          return;
        }
        final single = response.file;
        if (single != null) {
          if (!mounted) return;
          setState(() {
            _imagePath = single.path;
            _busy = true;
          });
          await _processImage(single.path);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('lost-data recovery failed: $e');
      }
    }
  }

  Future<void> _pickSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto struk pakai kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _scan(source);
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _parsed = null;
    });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (file == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      setState(() => _imagePath = file.path);
      await _processImage(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _processImage(String path) async {
    try {
      final raw = await OcrService.instance.recognizeFromPath(path);
      final parsed = ReceiptParser.parse(raw);
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal baca struk: $e';
        _busy = false;
      });
    }
  }

  void _useResult({bool autoSave = false}) {
    if (_parsed == null) return;
    Navigator.of(context).pop(ScanReceiptResult(
      amount: _parsed!.amount,
      merchant: _parsed!.merchant,
      date: _parsed!.date,
      imagePath: _imagePath,
      autoSave: autoSave,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Struk'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _busy
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Lagi baca struk...'),
                ],
              ),
            )
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _pickSource)
              : _parsed == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: _pickSource,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Pilih sumber foto'),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_imagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_imagePath!),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.auto_awesome,
                                    color: theme.colorScheme.primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Hasil deteksi (${(_parsed!.confidence * 100).round()}%)',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              _row('Toko', _parsed!.merchant ?? '—'),
                              _row(
                                'Total',
                                _parsed!.amount != null
                                    ? Money.format(_parsed!.amount!)
                                    : '—',
                              ),
                              _row(
                                'Tanggal',
                                _parsed!.date != null
                                    ? '${_parsed!.date!.day}/${_parsed!.date!.month}/${_parsed!.date!.year}'
                                    : '—',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          title: const Text('Lihat teks mentah'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                _parsed!.rawText,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickSource,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Foto ulang'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _parsed!.hasAnything
                                    ? () => _useResult()
                                    : null,
                                icon: const Icon(Icons.edit),
                                label: const Text('Cek dulu'),
                              ),
                            ),
                          ],
                        ),
                        if (_parsed!.amount != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _useResult(autoSave: true),
                              icon: const Icon(Icons.bolt),
                              label: const Text('Simpan langsung'),
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Gagal scan struk',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
