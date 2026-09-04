import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AlbumCoverCropPage extends StatefulWidget {
  final String imagePath;

  const AlbumCoverCropPage({super.key, required this.imagePath});

  @override
  State<AlbumCoverCropPage> createState() => _AlbumCoverCropPageState();
}

class _AlbumCoverCropPageState extends State<AlbumCoverCropPage> {
  final _boundaryKey = GlobalKey();
  final _transformation = TransformationController();
  late final Future<Size> _imageSize = _readImageSize();
  bool _saving = false;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  Future<Size> _readImageSize() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  Future<void> _saveCrop() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('裁剪区域尚未准备好');
      final image = await boundary.toImage(pixelRatio: 2.2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('无法生成封面图片');
      final temp = await getTemporaryDirectory();
      final output = File(p.join(
        temp.path,
        'album-cover-crop-${DateTime.now().millisecondsSinceEpoch}.png',
      ));
      await output.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, output.path);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('裁剪封面失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('裁剪相册封面'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveCrop,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('使用此封面', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Size>(
          future: _imageSize,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return const Center(
                child: Text('图片无法读取', style: TextStyle(color: Colors.white)),
              );
            }
            final sourceSize = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final cropWidth = constraints.maxWidth;
                final cropHeight = cropWidth * 9 / 16;
                final scale = (cropWidth / sourceSize.width)
                    .clamp(cropHeight / sourceSize.height, double.infinity);
                final displayWidth = sourceSize.width * scale;
                final displayHeight = sourceSize.height * scale;
                return Column(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '双指缩放，拖动图片，把想保留的部分放进裁剪框。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: SizedBox(
                          width: cropWidth,
                          height: cropHeight,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _transformation,
                              constrained: false,
                              minScale: 1,
                              maxScale: 6,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: displayWidth,
                                height: displayHeight,
                                child: Image.file(
                                  File(widget.imagePath),
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _transformation.value = Matrix4.identity(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('重置裁剪'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
