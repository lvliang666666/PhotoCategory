import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/security/private_album_controller.dart';
import '../../data/repositories/private_album_repository.dart';

class PrivateAlbumPasswordSetupPage extends StatefulWidget {
  final String albumName;

  const PrivateAlbumPasswordSetupPage({
    super.key,
    required this.albumName,
  });

  @override
  State<PrivateAlbumPasswordSetupPage> createState() =>
      _PrivateAlbumPasswordSetupPageState();
}

class _PrivateAlbumPasswordSetupPageState
    extends State<PrivateAlbumPasswordSetupPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      PrivateAlbumRepository.validatePassword(_password.text);
      if (_password.text != _confirm.text) {
        throw const FormatException('两次输入的密码不一致');
      }
      Navigator.pop(context, _password.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设置私密相册密码')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.lock_rounded, size: 64),
              const SizedBox(height: 18),
              Text(
                '保护「${widget.albumName}」',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                '封面仍会正常展示；进入相册查看照片时需要密码。子相册共享这个密码。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _PasswordField(
                controller: _password,
                label: '输入密码',
                errorText: _error,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirm,
                label: '再次输入密码',
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: const Text('保存密码'),
              ),
            ],
          ),
        ),
      );
}

class PrivateAlbumPasswordVerifyPage extends StatefulWidget {
  final int themeId;
  final String albumName;

  const PrivateAlbumPasswordVerifyPage({
    super.key,
    required this.themeId,
    required this.albumName,
  });

  @override
  State<PrivateAlbumPasswordVerifyPage> createState() =>
      _PrivateAlbumPasswordVerifyPageState();
}

class _PrivateAlbumPasswordVerifyPageState
    extends State<PrivateAlbumPasswordVerifyPage> {
  final _password = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking || _password.text.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final verified = await context
        .read<PrivateAlbumController>()
        .verifyAndUnlock(widget.themeId, _password.text);
    if (!mounted) return;
    if (verified) {
      Navigator.pop(context, true);
      return;
    }
    _password.clear();
    setState(() {
      _checking = false;
      _error = '密码不正确';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('验证私密相册')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64),
              const SizedBox(height: 18),
              Text(
                widget.albumName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('请输入该私密相册的密码查看照片', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _PasswordField(
                controller: _password,
                label: '相册密码',
                errorText: _error,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _checking ? null : _submit,
                child: _checking
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('进入相册'),
              ),
            ],
          ),
        ),
      );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _obscure,
        maxLength: 32,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ],
        textInputAction: widget.onSubmitted == null
            ? TextInputAction.next
            : TextInputAction.done,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: '6～32 位数字或英文字母',
          counterText: '',
          errorText: widget.errorText,
          prefixIcon: const Icon(Icons.password_rounded),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
          ),
        ),
      );
}
