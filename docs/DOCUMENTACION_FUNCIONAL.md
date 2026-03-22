# Documentación Funcional - Comunidad Bochil

## 1. Objetivo de la aplicación
Comunidad Bochil es una app móvil para participación ciudadana enfocada en:
- Reportar incidencias de agua e infraestructura.
- Dar seguimiento al estado de cada reporte.
- Participar en el foro comunitario.
- Recibir alertas oficiales y notificaciones de cambios de estado.

La app está construida con Flutter, usa Supabase como backend y Firebase Cloud Messaging para push notifications.

## 2. Perfiles y alcance funcional
### 2.1 Perfil ciudadano (implementado)
- Registro mediante invitación QR.
- Inicio de sesión por OTP SMS.
- Recuperación por enlace mágico (correo vinculado).
- Creación de reportes (públicos o privados).
- Voto de apoyo y comentarios en reportes.
- Participación en foro (crear temas, comentar, votar).
- Consulta y marcación de notificaciones.

### 2.2 Perfil administrador (no implementado en app móvil)
- Existe como concepto de rol en base de datos, pero no hay UI móvil administrativa.

## 3. Flujo de acceso y cuenta
## 3.1 Pantalla de bienvenida
Acciones disponibles:
- Iniciar sesión.
- Crear cuenta con código QR.

Ruta: /welcome

## 3.2 Registro de cuenta (flujo completo)
### Paso 1: Escaneo de QR
- Pantalla: Escanear Invitación.
- Se valida que el contenido sea UUID con formato válido.
- Se consulta la invitación en base de datos y debe estar no usada.
- Si es inválida o ya usada, se muestra error.

Ruta: /scanner

### Paso 2: Verificación por número de contrato
- El usuario ingresa su número de contrato.
- Debe coincidir con la invitación escaneada.
- Tiene máximo 3 intentos.
- Al exceder intentos, se limpia el flujo y se solicita escanear de nuevo.

Ruta: /contract-verify

### Paso 3: Captura de teléfono y envío OTP
- Se solicita teléfono (10 dígitos).
- Se normaliza con prefijo +52 si no viene con +.
- Se envía OTP SMS con Supabase Auth.

Ruta: /phone-input

### Paso 4: Verificación OTP y consolidación de perfil
- Se valida código OTP de 6 dígitos.
- Si venía del flujo QR:
  - Se crea perfil ciudadano en perfiles_usuarios.
  - Se intenta marcar invitación como usada.
- Si no venía de QR, se considera login normal.

Ruta: /otp-verify

Nota funcional:
- Existe manejo defensivo cuando falla el marcado de invitación por políticas RLS; el registro se considera exitoso si el perfil ya fue creado.

## 3.3 Inicio de sesión (usuario existente)
- Desde bienvenida, el usuario entra por teléfono + OTP.
- En este caso no se crea perfil; solo se autentica la sesión.

Rutas:
- /phone-input
- /otp-verify

## 3.4 Recuperación de acceso por correo
- El usuario puede abrir Recuperación desde la pantalla de teléfono.
- Captura correo y se solicita envío de magic link.
- El envío funciona solo si ese correo ya está vinculado a su cuenta.

Ruta: /recuperacion

## 3.5 Vinculación/actualización de correo en perfil
- Desde Perfil, el usuario puede:
  - Vincular correo si no tiene.
  - Actualizar correo existente.
- Se solicita confirmación por correo según reglas de Supabase.
- Se muestra estado visual:
  - Sin correo para recuperación.
  - Correo vinculado pendiente de confirmación.
  - Correo vinculado y confirmado.

## 3.6 Cierre de sesión
- Disponible en Perfil con confirmación.
- Elimina token push del dispositivo para el usuario actual.
- Cierra sesión y regresa a bienvenida.

## 3.7 Validación automática de sesión
- Al reanudar la app se valida que:
  - Sesión siga vigente.
  - Perfil exista en base de datos.
- Si no es válida, se cierra sesión y se redirige a bienvenida.

## 4. Navegación y rutas
## 4.1 Reglas de acceso
- Rutas públicas permitidas sin sesión:
  - /welcome
  - /scanner
  - /contract-verify
  - /phone-input
  - /otp-verify
  - /recuperacion
  - /notificaciones
- Cualquier otra ruta requiere usuario autenticado.

## 4.2 Estructura principal autenticada
Ruta raíz: /
Contiene 4 secciones por navegación inferior:
- Inicio (mapa de reportes).
- Comunidad (feed de reportes).
- Foro.
- Perfil.

## 4.3 Rutas funcionales adicionales
- /location-picker: selección de ubicación para nuevo reporte.
- /report-form: formulario de reporte.
- /reporte-detalle: detalle de reporte desde objeto en memoria.
- /reporte-detalle-id/:id: carga detalle por id (usado desde push/notificaciones).
- /foro/crear: creación de tema.
- /foro/detalle: detalle de tema.

## 5. Módulo de reportes
## 5.1 Inicio (mapa)
Funcionalidad:
- Mapa con teselas OpenStreetMap cacheadas.
- Muestra marcadores de:
  - Reportes sincronizados.
  - Reportes pendientes locales (sin internet).
- Al tocar marcador:
  - Abre vista rápida en bottom sheet.
  - Permite ir a detalle completo.

Acción principal:
- Botón Reportar Problema abre flujo de selección de ubicación.

## 5.2 Selección de ubicación
Funcionalidad:
- Obtiene ubicación GPS si hay permisos.
- Si GPS/permisos fallan, usa centro de Bochil.
- Hace reverse geocoding cuando hay internet.
- Restringe selección a límites del municipio (bounds definidos).
- Pasa ubicación + dirección + colonia al formulario.

## 5.3 Formulario de reporte
Datos capturados:
- Categoría (catálogo fijo).
- Título (requerido).
- Descripción (requerido).
- Privacidad:
  - Público (visible en feed comunitario).
  - Privado (visible solo para administración).
- Evidencia fotográfica:
  - Cámara o galería.
  - Máximo 3 fotos.

Comportamiento online:
- Sube fotos a Storage.
- Crea reporte en Supabase.
- Refresca providers de reportes.

Comportamiento offline:
- Guarda reporte en cola local SQLite (sync_queue).
- Conserva rutas de fotos locales.
- Muestra mensaje de envío automático cuando regrese internet.

## 5.4 Feed comunitario
Vista con 2 pestañas:
- Todos los reportes (solo públicos).
- Mis reportes (incluye pendientes locales).

Funcionalidad en el feed:
- Pull-to-refresh.
- Filtros avanzados (estado, categoría, colonia y orden).
- Banner de alertas oficiales (primera alerta destacada).
- Tarjetas con:
  - Autor.
  - Tiempo relativo.
  - Colonia.
  - Estado.
  - Categoría.
  - Imágenes.
  - Conteo de apoyos y comentarios.
- Acciones rápidas:
  - Apoyar (voto optimista).
  - Comentar.
  - Abrir detalle.

## 5.5 Detalle de reporte
Incluye:
- Galería de fotos.
- Categoría y estado actual.
- Título y descripción.
- Colonia, fecha y tiempo transcurrido/resolución.
- Seguimiento SLA (objetivo sugerido 72h).
- Timeline de cambios de estado.
- Botones:
  - Apoyar.
  - Comentar.
- Mini mapa con ubicación del reporte.

Regla de eliminación:
- Solo el autor puede eliminar.
- Solo si el estado actual es Pendiente.

## 5.6 Catálogos de negocio de reportes
Categorías disponibles:
- Fuga.
- Sin Agua.
- Baja Presión.
- Contaminación.
- Infraestructura.

Estados disponibles:
- Pendiente.
- En Revisión.
- En Progreso.
- Resuelto.

## 6. Módulo de foro comunitario
## 6.1 Vista general
Foro con 4 pestañas:
- Todos.
- Propuestas.
- Preguntas.
- Discusiones.

Cada tema muestra:
- Categoría.
- Título.
- Resumen.
- Autor.
- Fecha.
- Conteo de apoyos y comentarios.

## 6.2 Crear tema
Campos:
- Categoría.
- Título (mínimo 6 caracteres).
- Contenido (mínimo 12 caracteres).

Tras publicar:
- Refresca lista de temas.
- Muestra confirmación.

## 6.3 Detalle de tema
Incluye:
- Encabezado con categoría, autor y fecha.
- Contenido completo.
- Apoyo (voto con actualización optimista).
- Comentarios en lista.
- Caja para nuevo comentario.

Regla de eliminación:
- Solo el autor puede eliminar el tema.

## 6.4 Categorías de foro
- Propuesta.
- Pregunta.
- Discusión.
- Anuncio (disponible en modelo; no tiene pestaña dedicada en la pantalla principal).

## 7. Módulo de notificaciones
## 7.1 Tipos de notificaciones
- Alerta oficial.
- Estado de reporte.

## 7.2 Pantalla de notificaciones
Funcionalidad:
- Filtros:
  - Todas.
  - No leídas.
- Marcar individual al abrir.
- Marcar todas como leídas.
- Navegación contextual:
  - Si notificación tiene reporte_id, abre su detalle.

## 7.3 Regla de segmentación por calle (alertas)
- Si alerta aplica a todas las calles: la reciben todos.
- Si alerta define calles objetivo: se muestra/envía solo a usuarios cuya calle coincide.

## 8. Tiempo real (Realtime)
La app escucha cambios de base de datos y refresca con debounce para evitar recargas excesivas.

Suscripciones principales:
- Feed comunitario:
  - alertas_oficiales
  - reportes
  - historial_estados
- Detalle de reporte:
  - votos_reportes
  - historial_estados
  - reportes
- Detalle de tema:
  - comentarios_foro
  - votos_foro
- Notificaciones:
  - alertas_oficiales
  - historial_estados
  - notificaciones_lecturas (por usuario)

## 9. Push notifications
## 9.1 Flujo técnico
- La app inicializa Firebase Messaging y notificaciones locales.
- Registra/actualiza token del dispositivo en device_tokens.
- En foreground muestra notificación local.
- En tap abre:
  - detalle de reporte si hay reporte_id,
  - o pantalla de notificaciones como fallback.

## 9.2 Edge Function enviar-push
Origen de disparo:
- Insert en historial_estados.
- Insert en alertas_oficiales activas.

Comportamiento:
- Para cambios de estado:
  - busca dueño del reporte.
  - envía push a sus tokens.
- Para alertas:
  - envía a todos o filtra por calle según configuración.

## 10. Funcionamiento sin conexión
## 10.1 Detección de conectividad
- Se monitorea estado de red con connectivity_plus.
- Se muestra banner de Sin conexión en pantallas clave.

## 10.2 Cola local de reportes
- Base local sqflite: tabla sync_queue.
- Guarda reportes creados offline con fotos locales y estado de sincronización.

## 10.3 Sincronización automática
- Servicio singleton escucha reconexión.
- Procesa pendientes uno por uno:
  - marca sincronizando,
  - sube fotos,
  - crea reporte en servidor,
  - elimina entrada local,
  - limpia archivos temporales.
- Si falla un reporte, lo regresa a pendiente.

## 10.4 Caché de datos
- SharedPreferences:
  - Perfil.
  - Reportes de mapa.
  - Reportes enriquecidos del feed.
- Caché de mapa:
  - Teselas OSM en almacenamiento local para mejorar uso intermitente.

## 11. Perfil del usuario
Información mostrada:
- Nombre e inicial (avatar).
- Rol Ciudadano.
- Teléfono.
- Correo y estado de confirmación.
- Colonia.
- Calle.
- Número de contrato (si existe).

Acciones:
- Vincular/actualizar correo de recuperación.
- Cerrar sesión.

## 12. Entidades funcionales de datos
Principales tablas usadas:
- perfiles_usuarios.
- invitaciones_qr.
- reportes.
- historial_estados.
- comentarios_reportes.
- votos_reportes.
- temas_foro.
- comentarios_foro.
- votos_foro.
- alertas_oficiales.
- notificaciones_lecturas.
- device_tokens.

## 13. Reglas de negocio relevantes
- Registro ciudadano solo con invitación QR válida.
- Validación por número de contrato con 3 intentos.
- OTP SMS obligatorio para acceso.
- Recuperación por correo sujeta a correo previamente vinculado.
- Reporte privado no aparece en feed público.
- Eliminación de reporte solo para autor y estado Pendiente.
- Eliminación de tema solo para autor.
- Máximo 3 fotos por reporte.
- Ubicación del reporte restringida al área de Bochil.

## 14. Validaciones de entrada
- Teléfono: 10 dígitos (UI) y envío con +52.
- OTP: 6 dígitos.
- Correo: formato básico regex.
- Título y descripción de reporte: obligatorios.
- Tema foro:
  - Título mínimo 6 caracteres.
  - Contenido mínimo 12 caracteres.

## 15. Limitaciones y observaciones actuales
- Ruta /notificaciones está en whitelist pública; funcionalmente la data depende de usuario autenticado.
- Existe workaround por política RLS al marcar invitaciones QR como usadas.
- No hay paginación explícita en listas de comentarios (foro/reportes).
- No hay rate limiting funcional para toggles de voto.
- Cachés locales no tienen TTL explícito.
- La UX de recuperación por correo depende de que el usuario haya vinculado y confirmado correo antes.

## 16. Flujo resumido de extremo a extremo
1. Usuario se registra con QR, contrato, teléfono y OTP.
2. Ingresa a la app y crea reportes desde mapa.
3. Puede crear reportes públicos o privados, con fotos.
4. Si no hay internet, el reporte queda en cola y se sincroniza después.
5. La comunidad puede ver reportes públicos, apoyarlos y comentarlos.
6. El usuario da seguimiento al estado del reporte y su timeline.
7. Participa en foro con temas, apoyos y comentarios.
8. Recibe alertas oficiales y actualizaciones de sus reportes por notificación interna/push.
9. Gestiona su correo de recuperación y su sesión desde Perfil.

## 17. Fuentes de implementación revisadas
- Capa de entrada y navegación Flutter.
- Pantallas de autenticación, reportes, foro, notificaciones y perfil.
- Repositorios de acceso a datos Supabase.
- Servicios de sincronización, caché local, base local y push.
- Esquema de base de datos en docs/DATABASE.sql.
- Edge Function supabase/functions/enviar-push/index.ts.
