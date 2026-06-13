import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../theme/haptics.dart';
import '../data/measurements_repository.dart';

final _metricHistoryProvider =
    StreamProvider.family<List<BodyMeasurementData>, String>((ref, metric) {
  return ref.watch(measurementsRepositoryProvider).watchMetric(metric);
});

final _photosProvider =
    StreamProvider.family<List<ProgressPhotoData>, String>((ref, pose) {
  return ref.watch(measurementsRepositoryProvider).watchPhotos(pose: pose);
});

/// Body measurements (§17): per-metric history with a progress chart and a
/// bottom-anchored log action (§22 UI rule). Photos are tracked separately.
class MeasurementsView extends ConsumerStatefulWidget {
  const MeasurementsView({super.key});

  @override
  ConsumerState<MeasurementsView> createState() => _MeasurementsViewState();
}

class _MeasurementsViewState extends ConsumerState<MeasurementsView> {
  String _metric = 'bodyweight';

  static const _labels = <String, String>{
    'bodyweight': 'Bodyweight',
    'neck': 'Neck',
    'chest': 'Chest',
    'arms_l': 'Arm (L)',
    'arms_r': 'Arm (R)',
    'waist': 'Waist',
    'hips': 'Hips',
    'thigh_l': 'Thigh (L)',
    'thigh_r': 'Thigh (R)',
    'calf_l': 'Calf (L)',
    'calf_r': 'Calf (R)',
    'back': 'Back',
  };

  String get _unit => _metric == 'bodyweight' ? 'kg' : 'cm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(_metricHistoryProvider(_metric));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Measurements'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Metrics'), Tab(text: 'Photos')],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Metrics ──
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final m in MeasurementsRepository.builtInMetrics)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_labels[m] ?? m),
                              selected: _metric == m,
                              onSelected: (_) {
                                Haptics.selection();
                                setState(() => _metric = m);
                              },
                              selectedColor:
                                  AppColors.primaryContainer.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: history.when(
                      data: (rows) => rows.isEmpty
                          ? Center(
                              child: Text(
                                'No ${_labels[_metric]?.toLowerCase()} entries yet',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.secondary),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              children: [
                                if (rows.length >= 2) _chart(rows),
                                const SizedBox(height: 12),
                                for (final r in rows.reversed)
                                  _HistoryTile(
                                    row: r,
                                    unit: _unit,
                                    onDelete: () => ref
                                        .read(measurementsRepositoryProvider)
                                        .deleteMeasurement(r.id),
                                  ),
                              ],
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                  // Bottom-anchored primary action (§22).
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _logEntry(context),
                          icon: const Icon(Icons.add),
                          label: Text('Log ${_labels[_metric]}'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Tab 2: Progress Photos ──
            _PhotosTab(onAddPhoto: _capturePhoto),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    Haptics.light();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final pose = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in ['front', 'side', 'back'])
              ListTile(
                title: Text(p[0].toUpperCase() + p.substring(1)),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (pose == null || !mounted) return;

    final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (file == null || !mounted) return;

    await ref.read(measurementsRepositoryProvider).addPhoto(
          dateIso: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          pose: pose,
          filePath: file.path,
        );
  }

  Widget _chart(List<BodyMeasurementData> rows) {
    final spots = [
      for (final (i, r) in rows.indexed) FlSpot(i.toDouble(), r.value),
    ];
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logEntry(BuildContext context) async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Log ${_labels[_metric]}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: _unit),
          onSubmitted: (v) => Navigator.pop(dialogCtx, double.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogCtx, double.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) {
      await ref.read(measurementsRepositoryProvider).logMeasurement(
            dateIso: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            metric: _metric,
            value: value,
          );
    }
  }
}

class _PhotosTab extends ConsumerStatefulWidget {
  final VoidCallback onAddPhoto;
  const _PhotosTab({required this.onAddPhoto});

  @override
  ConsumerState<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends ConsumerState<_PhotosTab> {
  String _pose = 'front';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photosAsync = ref.watch(_photosProvider(_pose));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'front', label: Text('Front')),
                ButtonSegment(value: 'side', label: Text('Side')),
                ButtonSegment(value: 'back', label: Text('Back')),
              ],
              selected: {_pose},
              onSelectionChanged: (s) {
                Haptics.selection();
                setState(() => _pose = s.first);
              },
            ),
          ),
          Expanded(
            child: photosAsync.when(
              data: (photos) => photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_outlined,
                              size: 48,
                              color: AppColors.secondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No $_pose photos yet',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.secondary)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, i) {
                        final photo = photos[i];
                        return _PhotoCard(photo: photo,
                          onDelete: () => ref
                              .read(measurementsRepositoryProvider)
                              .deletePhoto(photo.id),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onAddPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Photo'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final ProgressPhotoData photo;
  final VoidCallback onDelete;
  const _PhotoCard({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(photo.filePath);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : Container(
                  color: AppColors.surfaceContainer,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.secondary),
                ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text(photo.dateIso,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              Haptics.medium();
              onDelete();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final BodyMeasurementData row;
  final String unit;
  final VoidCallback onDelete;

  const _HistoryTile(
      {required this.row, required this.unit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          '${row.value.toStringAsFixed(1)} $unit',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(row.dateIso),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
