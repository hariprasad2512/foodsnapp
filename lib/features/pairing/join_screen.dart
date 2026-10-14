import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/invite_code.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/invite_repository.dart';

/// S03 — Enter invite code (client only). Source of truth: UI spec §6 S03.
/// 6-box input, auto-uppercase, restricted to the invite alphabet so no
/// ambiguous characters can be typed. Pasting a full code distributes it.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  static const int _length = 6;
  late final List<TextEditingController> _boxes;
  late final List<FocusNode> _nodes;
  late final List<FocusNode> _listeners;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boxes = List.generate(_length, (_) => TextEditingController());
    _nodes = List.generate(_length, (_) => FocusNode());
    _listeners =
        List.generate(_length, (_) => FocusNode(skipTraversal: true));
  }

  @override
  void dispose() {
    for (final c in _boxes) {
      c.dispose();
    }
    for (final n in [..._nodes, ..._listeners]) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _boxes.map((c) => c.text).join();
  bool get _complete =>
      _code.length == _length && isValidInviteCode(_code);

  void _onBoxChanged(int index, String value) {
    // Pasted a full code into the first box → distribute it.
    if (index == 0 && value.length > 1) {
      final clean = value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
      for (var i = 0; i < _length; i++) {
        _boxes[i].text = i < clean.length ? clean[i] : '';
      }
      if (clean.length >= _length) {
        _nodes[_length - 1].requestFocus();
      } else {
        _nodes[clean.length].requestFocus();
      }
      setState(() => _error = null);
      return;
    }
    final char = value.isEmpty
        ? ''
        : value[value.length - 1].toUpperCase();
    // Reject chars outside the invite alphabet (no I, O, 0, 1).
    if (char.isNotEmpty && !inviteAlphabet.contains(char)) {
      _boxes[index].text = '';
      setState(() {});
      return;
    }
    _boxes[index].text = char;
    if (char.isNotEmpty && index < _length - 1) {
      _nodes[index + 1].requestFocus();
    }
    setState(() => _error = null);
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _boxes[index].text.isEmpty &&
        index > 0) {
      _nodes[index - 1].requestFocus();
      _boxes[index - 1].clear();
      setState(() => _error = null);
    }
  }

  Future<void> _connect() async {
    if (!_complete || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inviteRepositoryProvider).redeemInvite(_code);
      // Router moves to /home on the new relationship.
    } on RedeemFailure catch (e) {
      setState(() => _error = redeemErrorMessage(e.slug));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect with your dietician')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-character code she shared',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  _length,
                  (i) => SizedBox(
                    width: 48,
                    child: KeyboardListener(
                      focusNode: _listeners[i],
                      onKeyEvent: (e) => _onKey(i, e),
                      child: TextField(
                        controller: _boxes[i],
                        focusNode: _nodes[i],
                        enabled: !_busy,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        maxLength: i == 0 ? 6 : 1,
                        onChanged: (v) => _onBoxChanged(i, v),
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _complete && !_busy ? _connect : null,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
