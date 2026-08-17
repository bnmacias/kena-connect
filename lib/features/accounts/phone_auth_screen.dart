import 'package:flutter/material.dart';

import '../../accounts/domain/auth_controller.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_field.dart';
import '../../widgets/kena_glass_button.dart';

enum _PhoneStep { phone, otp, name }

/// Número → OTP → nombre (ver brief, sección 2) — sin contraseña en
/// ningún paso. El envío/verificación real del código pasa por
/// `VerificationProvider` (hoy, `MockVerificationProvider` — ver
/// `AccountsEnvironment`): cualquier código de 6 dígitos sirve mientras
/// no haya un `TwilioVerifyProvider` configurado.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  _PhoneStep _step = _PhoneStep.phone;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 6) {
      setState(() => _error = 'Ingresá un número válido, con código de país.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthController.instance.sendPhoneCode(phone);
      if (!mounted) return;
      setState(() => _step = _PhoneStep.otp);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos mandar el código. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmCode() {
    if (_codeController.text.trim().length < 4) {
      setState(() => _error = 'Ingresá el código que te mandamos.');
      return;
    }
    setState(() {
      _error = null;
      _step = _PhoneStep.name;
    });
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponele tu nombre.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthController.instance.verifyPhoneCode(
        _phoneController.text.trim(),
        _codeController.text.trim(),
        firstName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Código incorrecto o vencido.';
        _step = _PhoneStep.otp;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Continuar con teléfono')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStep(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: KenaSpacing.sm),
                  Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
                ],
                const SizedBox(height: KenaSpacing.lg),
                KenaGlassButton(
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.onAccent))
                      : Text(_primaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback get _primaryAction => switch (_step) {
        _PhoneStep.phone => _sendCode,
        _PhoneStep.otp => _confirmCode,
        _PhoneStep.name => _finish,
      };

  String get _primaryLabel => switch (_step) {
        _PhoneStep.phone => 'Mandar código',
        _PhoneStep.otp => 'Confirmar código',
        _PhoneStep.name => 'Empezar',
      };

  Widget _buildStep() {
    switch (_step) {
      case _PhoneStep.phone:
        return Column(
          key: const ValueKey('phone'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KenaField(
              label: 'Tu número',
              controller: _phoneController,
              hint: 'Ej: +54 9 11 2233 4455',
              autofocus: true,
            ),
          ],
        );
      case _PhoneStep.otp:
        return Column(
          key: const ValueKey('otp'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Te mandamos un código a ${_phoneController.text.trim()}.', style: KenaTypography.bodySmall),
            const SizedBox(height: KenaSpacing.md),
            KenaField(
              label: 'Código',
              controller: _codeController,
              hint: '123456',
              autofocus: true,
            ),
          ],
        );
      case _PhoneStep.name:
        return Column(
          key: const ValueKey('name'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KenaField(
              label: 'Tu nombre',
              controller: _nameController,
              hint: 'Como te van a ver los demás',
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        );
    }
  }
}
