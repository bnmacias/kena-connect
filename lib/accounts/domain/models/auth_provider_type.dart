/// Método con el que un [AppUser] inició sesión — determina qué datos
/// llegaron ya resueltos (login social) contra los que hubo que pedir a
/// mano (teléfono + OTP). Puramente informativo: una vez creado, un
/// [AppUser] se trata igual sin importar cómo entró.
enum AuthProviderType { google, apple, facebook, phone }
