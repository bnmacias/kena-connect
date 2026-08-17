/// Desacopla el envío/verificación de un código SMS del proveedor real
/// (ver brief, sección 3) — `PhoneAuthScreen` sólo conoce esta interfaz,
/// nunca a Twilio directamente. Cambiar de proveedor (o mockearlo para
/// tests/demo) es implementar esta clase de nuevo, sin tocar la UI.
abstract class VerificationProvider {
  /// Dispara el envío del código al número [phone] (formato E.164,
  /// p.ej. "+5491122334455"). Lanza si el proveedor no pudo iniciar la
  /// verificación (número inválido, servicio caído, etc.).
  Future<void> sendCode(String phone);

  /// `true` si [code] es el código vigente para [phone]. `false` (no
  /// una excepción) para un código incorrecto/vencido — es un resultado
  /// esperable del flujo, no una falla.
  Future<bool> verifyCode(String phone, String code);
}

/// Implementación real, pensada para Twilio Verify (ver brief, sección
/// 3) — pero Twilio Verify es una API server-to-server: la app nunca
/// debería tener su Account SID/Auth Token embebidos (se filtrarían del
/// APK). Por eso esta clase es un cliente delgado contra un backend
/// propio (`baseUrl`), que es quien de verdad habla con Twilio. Sin ese
/// backend desplegado, cualquier llamada acá falla explícitamente en
/// vez de simular un envío que nunca llegó a ningún lado.
class TwilioVerifyProvider implements VerificationProvider {
  const TwilioVerifyProvider({required this.baseUrl});

  /// URL del backend propio que efectivamente llama a Twilio Verify
  /// (`/v2/Services/.../Verifications`) — no configurado todavía.
  final String baseUrl;

  @override
  Future<void> sendCode(String phone) {
    throw UnimplementedError(
      'TwilioVerifyProvider necesita un backend real en "$baseUrl" que hable con '
      'Twilio Verify — no hay ninguno desplegado todavía. Usá MockVerificationProvider '
      'mientras tanto (ver AccountsEnvironment).',
    );
  }

  @override
  Future<bool> verifyCode(String phone, String code) {
    throw UnimplementedError(
      'TwilioVerifyProvider necesita un backend real en "$baseUrl" — ver sendCode().',
    );
  }
}

/// Para desarrollo/demo sin backend: "envía" el código instantáneamente
/// (no manda ningún SMS real) y acepta [fixedCode] como válido para
/// cualquier número. Es la que usa la app hoy (ver
/// `AccountsEnvironment`) hasta que exista un `TwilioVerifyProvider`
/// real configurado.
class MockVerificationProvider implements VerificationProvider {
  MockVerificationProvider({this.fixedCode = '123456'});

  final String fixedCode;
  final _sentTo = <String>{};

  @override
  Future<void> sendCode(String phone) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _sentTo.add(phone);
  }

  @override
  Future<bool> verifyCode(String phone, String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _sentTo.contains(phone) && code.trim() == fixedCode;
  }
}
