import 'package:flutter/material.dart';

class ClayAssets {
  ClayAssets._();

  static const photo = 'assets/ui/photo_icon.png';
  static const defaultCover = 'assets/ui/default_cover.png';
  static const gallery = 'assets/ui/gallery_grid.png';
  static const timeline = 'assets/ui/timeline_calendar.png';
  static const settings = 'assets/ui/settings_gear.png';
  static const add = 'assets/ui/add_button.png';
  static const importPhoto = 'assets/ui/import_photo.png';
  static const refreshButton = 'assets/ui/refresh_button.png';
  static const addPurple = 'assets/ui/add_purple.png';
}

class ClayAssetIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final double zoom;
  final int cacheWidth;
  final double radius;

  const ClayAssetIcon({
    super.key,
    required this.assetPath,
    required this.size,
    this.zoom = 1.7,
    this.cacheWidth = 128,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Transform.scale(
          scale: zoom,
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class ClayActionButton extends StatelessWidget {
  final String assetPath;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final double size;
  final double zoom;

  const ClayActionButton({
    super.key,
    required this.assetPath,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.size = 50,
    this.zoom = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: loading ? null : onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: onPressed == null ? .48 : 1,
                  child: ClayAssetIcon(
                    assetPath: assetPath,
                    size: size,
                    zoom: zoom,
                    cacheWidth: 192,
                    radius: size * .28,
                  ),
                ),
                if (loading)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
