import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/security/app_lock_controller.dart';

class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking || _pin.text.length != AppLockController.pinLength) return;
    final controller = context.read<AppLockController>();
    if (controller.lockRemaining > Duration.zero) return;
    setState(() => _checking = true);
    final success = await controller.verifyPin(_pin.text, unlockApp: true);
    if (!mounted || success) return;
    _pin.clear();
    _focus.requestFocus();
    setState(() {
      _checking = false;
      _error = controller.lockRemaining > Duration.zero
          ? null
          : '密码不正确，还可尝试 ${controller.remainingAttempts} 次';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppLockController>();
    final remaining = controller.lockRemaining;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 68, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 22),
                  Text('相册已锁定',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    remaining > Duration.zero
                        ? '尝试次数过多，请等待 ${remaining.inSeconds + 1} 秒'
                        : '请输入六位数字密码进入应用',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  _PinField(
                    controller: _pin,
                    focusNode: _focus,
                    enabled: remaining == Duration.zero && !_checking,
                    errorText: _error,
                    onCompleted: _submit,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: remaining == Duration.zero && !_checking
                        ? _submit
                        : null,
                    child: _checking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('解锁'),
                  ),
                  const SizedBox(height: 18),
                  Text('忘记密码时，需要在系统设置中清除本应用数据。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PinSetupPage extends StatefulWidget {
  final String title;

  const PinSetupPage({super.key, this.title = '设置应用锁'});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  String? _firstPin;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pin.text.length != AppLockController.pinLength) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin.text;
        _pin.clear();
        _error = null;
      });
      _focus.requestFocus();
      return;
    }
    if (_pin.text != _firstPin) {
      setState(() {
        _pin.clear();
        _error = '两次输入不一致，请重新确认';
      });
      _focus.requestFocus();
      return;
    }
    Navigator.pop(context, _pin.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.password_rounded,
                        size: 62, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 20),
                    Text(_firstPin == null ? '输入六位密码' : '再次输入密码',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      _firstPin == null ? '密码仅用于本机应用锁，请妥善记住。' : '请再次输入，确认密码无误。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    _PinField(
                      controller: _pin,
                      focusNode: _focus,
                      errorText: _error,
                      onCompleted: _submit,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_firstPin == null ? '下一步' : '确认密码'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class PinVerifyPage extends StatefulWidget {
  final String title;
  final String subtitle;

  const PinVerifyPage({
    super.key,
    required this.title,
    this.subtitle = '请输入当前六位密码进行验证',
  });

  @override
  State<PinVerifyPage> createState() => _PinVerifyPageState();
}

class _PinVerifyPageState extends State<PinVerifyPage> {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pin.text.length != AppLockController.pinLength) return;
    final lock = context.read<AppLockController>();
    if (lock.lockRemaining > Duration.zero) return;
    if (await lock.verifyPin(_pin.text)) {
      if (mounted) Navigator.pop(context, true);
      return;
    }
    _pin.clear();
    _focus.requestFocus();
    if (mounted) {
      setState(() => _error = lock.lockRemaining > Duration.zero
          ? null
          : '密码不正确，还可尝试 ${lock.remainingAttempts} 次');
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = context.watch<AppLockController>().lockRemaining;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 62),
                  const SizedBox(height: 20),
                  Text(widget.subtitle, textAlign: TextAlign.center),
                  if (remaining > Duration.zero) ...[
                    const SizedBox(height: 8),
                    Text('请等待 ${remaining.inSeconds + 1} 秒后再试',
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  _PinField(
                    controller: _pin,
                    focusNode: _focus,
                    enabled: remaining == Duration.zero,
                    errorText: _error,
                    onCompleted: _submit,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: remaining == Duration.zero ? _submit : null,
                    child: const Text('验证'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final VoidCallback onCompleted;

  const _PinField({
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.errorText,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: true,
        obscureText: true,
        obscuringCharacter: '●',
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              letterSpacing: 12,
            ),
        maxLength: AppLockController.pinLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: '••••••',
          counterText: '',
          errorText: errorText,
        ),
        onChanged: (value) {
          if (value.length == AppLockController.pinLength) onCompleted();
        },
        onSubmitted: (_) => onCompleted(),
      );
}
