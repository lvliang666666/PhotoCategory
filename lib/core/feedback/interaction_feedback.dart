import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InteractionFeedbackController extends ChangeNotifier {
  static const _enabledKey = 'interaction_haptic_feedback_enabled';

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (value) await HapticFeedback.selectionClick();
  }
}

class InteractionFeedbackLayer extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const InteractionFeedbackLayer({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  State<InteractionFeedbackLayer> createState() =>
      _InteractionFeedbackLayerState();
}

class _InteractionFeedbackLayerState extends State<InteractionFeedbackLayer> {
  int? _activePointer;
  Offset? _downPosition;
  DateTime? _downTime;
  bool _moved = false;
  DateTime? _lastFeedbackAt;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!widget.enabled || _activePointer != null) return;
        _activePointer = event.pointer;
        _downPosition = event.position;
        _downTime = DateTime.now();
        _moved = false;
      },
      onPointerMove: (event) {
        if (event.pointer != _activePointer || _downPosition == null) return;
        if ((event.position - _downPosition!).distance > 12) _moved = true;
      },
      onPointerUp: _handlePointerUp,
      onPointerCancel: (event) {
        if (event.pointer == _activePointer) _reset();
      },
      child: widget.child,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    final elapsed = _downTime == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_downTime!);
    final shouldFeedback = widget.enabled &&
        !_moved &&
        elapsed >= const Duration(milliseconds: 25) &&
        elapsed <= const Duration(milliseconds: 480);
    _reset();
    if (!shouldFeedback) return;
    final now = DateTime.now();
    if (_lastFeedbackAt != null &&
        now.difference(_lastFeedbackAt!) < const Duration(milliseconds: 45)) {
      return;
    }
    _lastFeedbackAt = now;
    HapticFeedback.selectionClick();
  }

  void _reset() {
    _activePointer = null;
    _downPosition = null;
    _downTime = null;
    _moved = false;
  }
}
