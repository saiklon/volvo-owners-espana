# Volvo Owners España

Comunidad independiente de propietarios Volvo en España. Sitio estático publicado en GitHub Pages, con registro, autenticación y gestión de socios conectados a Supabase.

## Web

https://saiklon.github.io/volvo-owners-espana/

## Módulo de socios

- Registro con correo y contraseña.
- Confirmación de correo y recuperación de contraseña mediante Supabase Auth.
- Perfil de socio con nombre visible, localidad y provincia.
- Alta de uno o varios Volvo con modelo, año, motor, acabado, fotografía y breve historia.
- Fotografías en bucket privado, con límite de 8 MB y formatos JPG, PNG y WEBP.
- Revisión manual por administración.
- Galería privada de vehículos aprobados, visible únicamente para socios aprobados.
- Panel de administración con contadores, filtros y acciones de aprobar/rechazar.

## Puesta en marcha de Supabase

1. Crea un proyecto en https://supabase.com/.
2. En **SQL Editor**, ejecuta el contenido completo de `supabase/schema.sql`.
3. En **Authentication → URL Configuration**, establece como Site URL la web del proyecto y añade a Redirect URLs:
   - `https://saiklon.github.io/volvo-owners-espana/socios.html`
   - `https://saiklon.github.io/volvo-owners-espana/*`
4. En **Project Settings → API**, copia la Project URL y la clave pública anon/publishable.
5. Crea localmente `config.js` a partir de `config.example.js` y sustituye la URL y la clave pública anon/publishable.
6. Para GitHub Pages, publica ese `config.js` en la raíz del sitio. Como está excluido por `.gitignore`, tendrás que añadirlo explícitamente con `git add -f config.js` antes de hacer commit. La URL y la clave anon/publishable son públicas por diseño; la seguridad depende de RLS y de las políticas de Storage. **Nunca incluyas la clave service_role**.
7. Comprueba que el bucket privado `vehicle-photos` se ha creado al ejecutar el SQL y que las políticas RLS aparecen activas.

### Importante sobre GitHub Pages y config.js

GitHub Pages no ofrece variables de entorno secretas para JavaScript estático. La URL de Supabase y la clave anon/publishable son visibles en el navegador por diseño; la seguridad depende de las políticas RLS, Storage y Auth del esquema. La clave `service_role` jamás debe estar en el cliente ni en el repositorio.

## Crear el primer administrador

1. Registra una cuenta desde `socios.html` y confirma el correo.
2. Cuando el perfil se haya creado, abre Supabase → SQL Editor.
3. Ejecuta, sustituyendo el correo por el tuyo:

```sql
update public.profiles
set role='admin', membership_status='approved'
where email='TU_CORREO';
```

4. Cierra sesión y vuelve a entrar. Verás el panel **Administración del club** dentro de la página de socios.

No existe una URL administrativa pública independiente: el panel solo se muestra a una cuenta cuyo rol de base de datos sea `admin`, y las operaciones también están protegidas por RLS.

## Flujo de alta

1. La persona crea una cuenta.
2. Confirma su dirección de correo si Supabase tiene activada la confirmación.
3. Inicia sesión y completa la ficha de su Volvo.
4. La foto se guarda en Storage privado y la solicitud queda como `pending`.
5. Administración revisa y aprueba o rechaza.
6. Al aprobar un vehículo, el perfil pasa a socio aprobado y puede acceder a la galería privada.

## Protección de datos: pendiente antes de abrir el registro

`privacy.html` sigue siendo un borrador. **No se deben aceptar altas reales hasta completarlo y revisarlo** con la identidad del responsable, NIF, domicilio, contacto, finalidades, bases jurídicas, conservación, derechos, encargados y demás información exigible. También hay que definir un canal para ejercer derechos y una política de moderación/eliminación de fotos y cuentas.

## Marca

Volvo Owners España es un proyecto independiente, no afiliado, patrocinado ni respaldado por Volvo Cars. No utiliza el logotipo oficial.


## Alta de socio con presentación obligatoria del Volvo

El formulario de registro solicita en un único proceso los datos personales y la ficha del primer vehículo. Para crear la cuenta es obligatorio indicar modelo y año, escribir una historia de al menos 30 caracteres, adjuntar una fotografía JPG/PNG/WEBP de hasta 8 MB y aceptar las declaraciones de propiedad/autorización y publicación dentro del club.

Si Supabase exige confirmar el correo antes de crear una sesión, la ficha y el archivo fotográfico se conservan temporalmente en IndexedDB en el mismo navegador. Tras confirmar el correo y volver a iniciar sesión desde ese navegador, la web sube la fotografía al bucket privado vehicle-photos y crea el vehículo con estado pending. Si el alta devuelve una sesión inmediatamente, la ficha se guarda en ese momento. El usuario no obtiene acceso de socio hasta que administración aprueba el vehículo.
