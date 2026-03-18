# Documentacion Funcional Actual - SAPAM Bochil

Fecha de corte: 18 de marzo de 2026

Este documento resume lo que ya esta implementado en la app Flutter, basado en el codigo actual y en la estructura de base de datos definida en [debug.md](debug.md) como version limpia y mas reciente, complementada por [contexto.md](contexto.md).

## 1. Arquitectura General

- Frontend: Flutter (Material 3).
- Estado y DI: Riverpod.
- Navegacion: GoRouter.
- Backend: Supabase (Auth + Postgres + Storage).
- Mapas: OpenStreetMap con flutter_map.
- Funcionalidad offline:
  - Cache de perfil y reportes en SharedPreferences.
  - Cola local de reportes en sqflite.
  - Sincronizacion automatica al recuperar conexion.

## 2. Modulos Implementados

## 2.1 Autenticacion y Registro

### Diseno del flujo

Hay 2 caminos de acceso:

1. Login normal (usuario ya registrado)
- Pantallas: bienvenida -> telefono -> OTP.
- Proceso:
  - Se envia OTP por SMS con Supabase Auth.
  - Se valida el codigo OTP.
  - Si es usuario existente, entra directo.

2. Registro con invitacion QR
- Pantallas: bienvenida -> scanner QR -> validar contrato -> telefono -> OTP.
- Proceso:
  - Se escanea un UUID en QR.
  - Se valida que exista invitacion disponible (no usada).
  - Se compara numero de contrato capturado por el usuario.
  - Se envia y verifica OTP.
  - Al verificar OTP:
    - Se crea perfil en perfiles_usuarios.
    - Se marca invitacion_qr como usada.

### Tablas involucradas

- auth.users (gestionada por Supabase Auth)
  - Alta/autenticacion por OTP.
- invitaciones_qr
  - SELECT para validar QR.
  - UPDATE para marcar usado/usado_por/fecha_uso.
- perfiles_usuarios
  - INSERT en registro inicial.
  - SELECT para cargar perfil del usuario actual.

### Recuperacion de acceso por correo (magic link)

- Flujo:
  - Pantalla publica de recuperacion por correo.
  - Envio de magic link con Supabase Auth.
  - Reingreso a la app mediante enlace seguro.
- Operacion adicional relevante:
  - Al cerrar sesion, se limpia token de dispositivo para evitar push a sesiones cerradas.

## 2.2 Inicio (Mapa principal)

### Que hace

- Muestra mapa de Bochil con marcadores de reportes sincronizados.
- Permite abrir resumen rapido de cada reporte y navegar al detalle.
- Muestra reportes pendientes locales (sincronizacion pendiente) con marcador distinto.
- Permite iniciar creacion de nuevo reporte desde FAB "Reportar Problema".

### Tablas involucradas

- reportes
  - SELECT para mostrar todos los reportes en mapa.

### Datos locales involucrados

- sync_queue (sqflite local)
  - Lectura de reportes pendientes para mostrarlos en mapa mientras no se sincronizan.

## 2.3 Creacion de Reportes

### Flujo funcional

1. Seleccion de ubicacion
- Obtiene GPS si hay permisos.
- Limita seleccion geograficamente al municipio (bounds configurados).
- Hace reverse geocoding cuando hay internet para direccion/colonia.

2. Formulario de reporte
- Campos:
  - categoria
  - titulo
  - descripcion
  - coordenadas
  - hasta 3 fotos
  - privacidad (publico/privado)
- Si hay internet:
  - Sube imagenes al bucket evidencia_reportes.
  - Inserta reporte en Supabase.
- Si no hay internet:
  - Guarda reporte en cola local (sqflite) para envio posterior automatico.

### Tablas y storage involucrados

- reportes
  - INSERT de nuevo reporte.
- storage.buckets / storage.objects (bucket evidencia_reportes)
  - INSERT de archivos (upload) y generacion de URL publica.

### Datos locales involucrados

- sync_queue (sqflite)
  - INSERT del reporte pendiente offline.

## 2.4 Feed Comunitario

### Que hace

- Tiene dos tabs:
  - "Todos los reportes": solo reportes publicos.
  - "Mis reportes": reportes del usuario + pendientes locales.
- Renderiza cards tipo red social con:
  - autor
  - estado
  - categoria
  - fotos
  - votos y comentarios
- Permite votar y comentar desde la card.
- Incluye pull-to-refresh.
- Incluye filtros locales avanzados en "Todos los reportes":
  - categoria
  - estado
  - colonia
  - fecha (rango)
- Se compacto la seccion de alertas para mostrar solo destacada y acceso a centro completo.

### Tablas involucradas

- reportes
  - SELECT de reportes enriquecidos (incluye join con autor).
  - Filtro local por es_publico y por usuario actual.
- perfiles_usuarios
  - SELECT para perfil propio.
- perfiles_publicos
  - SELECT para nombre del autor (nombre_completo).
- votos_reportes
  - SELECT para conteos y voto del usuario.
  - INSERT/DELETE para toggle de voto.
- comentarios_reportes
  - SELECT para conteo de comentarios.

### Nota importante

- El feed tambien consulta alertas_oficiales para mostrar banner compacto.
- Esta tabla SI esta definida en [debug.md](debug.md), junto con su RLS y politica de lectura de alertas activas.

## 2.5 Detalle del Reporte

### Que hace

- Muestra informacion completa:
  - galeria de fotos
  - categoria, estado, descripcion, colonia, fecha
  - mini mapa de ubicacion
- Permite:
  - votar (apoyar)
  - abrir comentarios
  - eliminar reporte propio solo si esta en estado Pendiente
- Incluye timeline visual de estado/SLA del reporte a partir de historial de cambios.

### Tablas involucradas

- reportes
  - DELETE para eliminar reporte propio.
- votos_reportes
  - SELECT para estado de voto y conteo.
  - INSERT/DELETE por toggle.
- comentarios_reportes
  - Lectura/escritura mediante modal de comentarios.
- historial_estados
  - SELECT para timeline de estados por reporte.

## 2.6 Foro Comunitario (Ampliado)

### Que hace

- Agrega una pestaña dedicada de Foro dentro de la navegacion principal.
- Permite crear temas comunitarios por categoria:
  - Propuesta
  - Pregunta
  - Discusion
  - Anuncio
- Muestra feed de temas con autor, votos y conteo de comentarios.
- Permite entrar al detalle del tema para comentar y votar.

### Tablas involucradas

- temas_foro
  - SELECT de temas activos.
  - INSERT para crear tema propio.
  - UPDATE/DELETE para gestionar tema propio.
- comentarios_foro
  - SELECT por tema.
  - INSERT de comentario propio.
- votos_foro
  - SELECT para conteo y voto del usuario.
  - INSERT/DELETE para toggle de voto.
- perfiles_usuarios
  - SELECT para datos propios.
- perfiles_publicos
  - SELECT para nombre de autor en temas y comentarios.

## 2.7 Comentarios (Reportes)

### Que hace

- Abre un bottom sheet con lista de comentarios por reporte.
- Muestra autor y tiempo relativo.
- Permite publicar comentario nuevo.

### Tablas involucradas

- comentarios_reportes
  - SELECT de comentarios por reporte.
  - INSERT de nuevo comentario.
- perfiles_usuarios
  - SELECT para datos propios.
- perfiles_publicos
  - SELECT para nombre del autor en cada comentario.

## 2.8 Perfil

### Que hace

- Muestra datos del usuario autenticado:
  - nombre
  - telefono
  - email (cuando esta registrado)
  - colonia
  - numero de contrato
- Permite cerrar sesion.
- Si falla red, usa cache local de perfil cuando existe.

### Tablas involucradas

- perfiles_usuarios
  - SELECT del perfil actual.
- auth.users
  - signOut para cerrar sesion.

### Datos locales involucrados

- SharedPreferences
  - Cache de perfil para lectura offline.

## 2.9 Centro de Notificaciones

### Que hace

- Consolida notificaciones de dos origenes:
  - alertas oficiales
  - cambios de estado de mis reportes
- Permite marcar notificaciones como leidas por usuario.
- Se integra con push: al tocar notificacion remota sin reporte_id, abre este centro.

### Tablas involucradas

- alertas_oficiales
  - SELECT de alertas activas para fuente de notificaciones.
- historial_estados
  - SELECT de cambios de estado para reportes del usuario.
- reportes
  - SELECT para relacionar estado con reporte propio.
- notificaciones_lecturas
  - SELECT para estado leida/no leida.
  - INSERT/UPDATE/DELETE para persistencia de lectura por usuario.

## 2.10 Notificaciones Push

### Que hace

- Registra token FCM por dispositivo y plataforma.
- Recibe push en background y foreground.
- En foreground muestra notificacion local real para mejorar UX.
- Al tocar una notificacion:
  - si incluye reporte_id, abre detalle de reporte.
  - si no incluye reporte_id, abre centro de notificaciones.

### Tablas y backend involucrados

- device_tokens
  - SELECT/INSERT/UPDATE/DELETE de tokens propios.
- historial_estados / alertas_oficiales
  - Origen funcional de eventos de notificacion.
- Supabase Edge Functions
  - Funcion server-side para envio push via FCM v1.

## 2.11 Sincronizacion Offline y Cache

### Sincronizacion automatica

- Servicio en background que escucha conectividad.
- Cuando vuelve internet:
  - toma reportes pendientes de sync_queue
  - sube fotos locales
  - crea reporte en reportes
  - elimina pendiente local
  - limpia archivos temporales de fotos

### Cache de lectura

- Se cachean:
  - perfil
  - reportes de mapa
  - reportes enriquecidos del feed
- Si Supabase falla, la UI intenta responder con cache.

### Tablas y almacenamiento involucrados

- reportes (INSERT al sincronizar)
- evidencia_reportes en Storage (upload de fotos)
- almacenamiento local:
  - sync_queue (sqflite)
  - SharedPreferences (cache)

## 3. Matriz Modulo vs Tabla

| Modulo | Tabla/Storage | Operaciones actuales |
|---|---|---|
| Registro con QR | invitaciones_qr | SELECT, UPDATE |
| Registro con QR | perfiles_usuarios | INSERT |
| Login OTP | auth.users | OTP sign-in / verify |
| Perfil | perfiles_usuarios | SELECT |
| Home mapa | reportes | SELECT |
| Crear reporte | reportes | INSERT |
| Crear reporte | storage.objects (evidencia_reportes) | INSERT (upload), URL publica |
| Feed comunitario | reportes | SELECT |
| Feed comunitario | perfiles_publicos | SELECT para autor |
| Feed comunitario | votos_reportes | SELECT, INSERT, DELETE |
| Feed comunitario | comentarios_reportes | SELECT |
| Feed comunitario | alertas_oficiales | SELECT (banner compacto) |
| Feed comunitario | historial_estados | SELECT (estado/timeline en detalle) |
| Comentarios | comentarios_reportes | SELECT, INSERT |
| Comentarios | perfiles_publicos | SELECT para autor |
| Detalle reporte | reportes | DELETE (propio en Pendiente) |
| Detalle reporte | votos_reportes | SELECT, INSERT, DELETE |
| Detalle reporte | historial_estados | SELECT |
| Foro comunitario | temas_foro | SELECT, INSERT, UPDATE, DELETE |
| Foro comunitario | comentarios_foro | SELECT, INSERT, DELETE |
| Foro comunitario | votos_foro | SELECT, INSERT, DELETE |
| Foro comunitario | perfiles_publicos | SELECT para autor |
| Centro de notificaciones | alertas_oficiales | SELECT |
| Centro de notificaciones | historial_estados | SELECT |
| Centro de notificaciones | reportes | SELECT |
| Centro de notificaciones | notificaciones_lecturas | SELECT, INSERT, UPDATE, DELETE |
| Push notifications | device_tokens | SELECT, INSERT, UPDATE, DELETE |
| Recuperacion por email | auth.users | magic link (OTP por correo) |

## 4. Pantallas Disponibles y Estado

- En uso dentro del flujo principal:
  - Welcome, Scanner, ContractVerify, PhoneInput, OTPVerify
  - Recuperacion
  - MainScaffold (Inicio, Comunidad, Foro, Perfil)
  - LocationPicker, ReportForm, ReporteDetalle, ReporteDetalleLoader
  - Foro, CrearTema, TemaDetalle
  - Notificaciones
- Retirada para evitar duplicidad funcional:
  - MisReportesScreen (la vista oficial de "Mis reportes" es la pestaña dentro de Comunidad)

## 5. Consideraciones Tecnicas Relevantes

- La app depende de politicas RLS para permitir operaciones de ciudadano autenticado.
- Se incorporo centro de notificaciones con persistencia de lectura por usuario (tabla notificaciones_lecturas).
- Se incorporo historial de estados para trazabilidad y timeline del ciclo de vida de reportes.
- Push notifications operan con FCM v1 desde funcion server-side, no con API legado.
- El cliente movil debe usar clave publishable/anon publica, nunca service_role.
- Se observa una implementacion dual de sincronizacion offline:
  - En uso: SyncService + LocalDatabaseService (sqflite).
  - Legada/no conectada al flujo actual: OfflineSyncService (SharedPreferences).
- Para referencia tecnica del esquema actual, usar primero [debug.md](debug.md) y despues [contexto.md](contexto.md) como historial/soporte.

## 6. Resumen Ejecutivo

Actualmente ya esta implementado el flujo ciudadano end-to-end:

1. Registro/autenticacion por OTP con validacion de invitacion QR.
2. Captura y envio de reportes geolocalizados con evidencia fotografica.
3. Mapa de reportes y detalle completo.
4. Feed comunitario con privacidad, votos y comentarios.
5. Foro comunitario ampliado con creacion de temas, votos y comentarios.
6. Timeline de estados/SLA por reporte con trazabilidad historica.
7. Centro de notificaciones unificado (alertas + cambios de estado) con lecturas por usuario.
8. Notificaciones push end-to-end con deep-link contextual.
9. Recuperacion de acceso por email (magic link).
10. Perfil de usuario con cierre de sesion y limpieza de token de push.
11. Operacion offline real con cola local y sincronizacion automatica.

Con esto, la app ya cubre las funcionalidades nucleares para ciudadanos en produccion temprana, con integracion completa a Supabase y soporte de conectividad intermitente.

## 7. Estado por Tabla (Auditoria Funcional)

Esta seccion consolida, por cada tabla principal, su estado funcional actual con base en [debug.md](debug.md) y el codigo de la app.

### 7.1 public.invitaciones_qr

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - curp
  - numero_contrato
  - nombre_titular
  - direccion
  - colonia
  - usado, usado_por, fecha_uso
- Politicas RLS relevantes:
  - SELECT permitido (lectura de invitaciones para validacion QR).
  - UPDATE permitido para usuario autenticado (marcar invitacion usada).
- Uso en app:
  - Validacion del QR en flujo de registro.
  - Marcado de invitacion como usada tras consolidar registro.

### 7.2 public.perfiles_usuarios

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - rol
  - nombre_completo
  - curp
  - numero_contrato
  - direccion
  - colonia
  - telefono
  - email
  - invitacion_id
- Politicas RLS relevantes:
  - SELECT solo perfil propio (auth.uid() = id).
  - INSERT de perfil propio en registro.
- Uso en app:
  - Creacion de perfil en alta inicial (registro QR + OTP).
  - Consulta de perfil para pantalla de Perfil.
  - Datos de usuario autenticado y trazabilidad interna.

### 7.3 public.perfiles_publicos (VIEW)

- Estado: Implementada para consumo publico seguro.
- Campos clave usados por app:
  - id
  - nombre_completo
- Seguridad relevante:
  - Solo expone nombre publico, sin datos sensibles.
- Uso en app:
  - Mostrar nombre de autor en feed, comentarios y foro.

### 7.4 public.reportes

- Estado: Implementada y en uso intensivo.
- Campos clave usados por app:
  - id
  - usuario_id
  - asignado_a
  - titulo
  - categoria
  - descripcion
  - colonia
  - ubicacion (POINT)
  - latitud, longitud (generadas)
  - fotos_urls
  - estado
  - es_publico
  - votos_apoyo (presente por compatibilidad)
  - created_at, updated_at
- Politicas RLS relevantes:
  - SELECT publico (lectura de reportes).
  - INSERT solo a nombre del usuario autenticado.
  - UPDATE solo reporte propio.
  - DELETE solo reporte propio.
- Uso en app:
  - Mapa principal (lectura).
  - Feed comunitario y detalle (lectura).
  - Creacion de reportes (online y sincronizacion offline).
  - Eliminacion de reporte propio en estado Pendiente (regla de UI).

### 7.5 public.votos_reportes

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - reporte_id
  - usuario_id
  - created_at
- Politicas RLS relevantes:
  - SELECT publico.
  - INSERT para voto del propio usuario.
  - DELETE para retirar voto del propio usuario.
- Uso en app:
  - Conteo de apoyos por reporte.
  - Verificacion de voto activo del usuario.
  - Toggle votar/quitar voto.

### 7.6 public.comentarios_reportes

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - reporte_id
  - usuario_id
  - comentario
  - created_at
- Politicas RLS relevantes:
  - SELECT publico.
  - INSERT para comentario del propio usuario.
- Uso en app:
  - Listado de comentarios por reporte.
  - Alta de comentarios desde bottom sheet.
  - Conteo de comentarios en feed.

### 7.7 public.alertas_oficiales

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - titulo
  - mensaje
  - nivel_urgencia
  - activa
  - created_at
- Politicas RLS relevantes:
  - SELECT de alertas activas (activa = true).
- Uso en app:
  - Banner compacto de alertas oficiales en modulo Comunidad.
  - Fuente del centro de notificaciones.

### 7.8 public.historial_estados

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - reporte_id
  - estado_anterior
  - estado_nuevo
  - cambiado_por
  - comentario
  - created_at
- Politicas RLS relevantes:
  - SELECT abierto para lectura de historial de reportes.
- Uso en app:
  - Timeline de estados en detalle de reporte.
  - Fuente del centro de notificaciones para cambios de estado.

### 7.9 public.device_tokens

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - usuario_id
  - token
  - plataforma
  - created_at
  - updated_at
- Politicas RLS relevantes:
  - SELECT/INSERT/UPDATE/DELETE restringido a token propio.
- Uso en app:
  - Registro y mantenimiento de tokens FCM del usuario autenticado.
  - Limpieza de token al cerrar sesion.

### 7.10 public.temas_foro

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - usuario_id
  - titulo
  - categoria
  - contenido
  - votos_apoyo
  - activo
  - created_at
  - updated_at
- Politicas RLS relevantes:
  - SELECT de temas activos.
  - INSERT/UPDATE/DELETE de tema propio.
- Uso en app:
  - Feed del foro por categoria.
  - Creacion y gestion de temas comunitarios.

### 7.11 public.comentarios_foro

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - tema_id
  - usuario_id
  - comentario
  - created_at
- Politicas RLS relevantes:
  - SELECT publico.
  - INSERT de comentario propio.
  - DELETE de comentario propio.
- Uso en app:
  - Conversacion dentro del detalle de tema de foro.

### 7.12 public.votos_foro

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - tema_id
  - usuario_id
  - created_at
- Politicas RLS relevantes:
  - SELECT publico.
  - INSERT/DELETE de voto propio.
- Uso en app:
  - Reaccion de apoyo en temas de foro.

### 7.13 public.notificaciones_lecturas

- Estado: Implementada y en uso.
- Campos clave usados por app:
  - id
  - usuario_id
  - tipo
  - origen_id
  - read_at
- Politicas RLS relevantes:
  - SELECT/INSERT/UPDATE/DELETE solo para lecturas propias.
- Uso en app:
  - Persistir estado leida/no leida del centro de notificaciones.

### 7.14 storage.objects (bucket evidencia_reportes)

- Estado: Implementada y en uso.
- Configuracion relevante:
  - Bucket publico evidencia_reportes.
- Politicas relevantes:
  - SELECT publico para visualizar evidencias.
  - INSERT autenticado para subir fotos.
- Uso en app:
  - Carga de evidencia fotografica al crear reporte.
  - Lectura de URL publica en cards/detalle.

### 7.15 auth.users (Supabase Auth)

- Estado: Implementada y en uso.
- Operaciones usadas por app:
  - signInWithOtp (envio SMS).
  - verifyOtp (validacion de codigo).
  - signInWithOtp via email (magic link).
  - signOut.
- Uso en app:
  - Login de usuarios existentes.
  - Registro de nuevos usuarios (combinado con invitaciones y perfil).
