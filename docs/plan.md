# Plan: Completar Features Propuesta SAPAM Bochil

## TL;DR
Implementar las 6 features faltantes de la propuesta técnica original para completar la experiencia del ciudadano: edición de perfil, filtros de búsqueda, SLA/timeline de reportes, recuperación por email, foro comunitario ampliado y notificaciones push con Firebase. Se organiza en 3 fases por complejidad creciente y dependencias.

---

### Step 2: Filtros de Búsqueda en el Feed (*paralelo con step 1*)
**Objetivo:** Filtrar reportes por categoría, estado, fecha y colonia en el feed comunitario.

**DB:** Ningún cambio — los campos ya existen en `reportes`.

**App — archivos a modificar/crear:**
- **NUEVO** `lib/widgets/filtros_reportes_sheet.dart` — BottomSheet con:
  - Chips/dropdown para `CategoriaReporte` (Fuga, Sin Agua, etc.)
  - Chips/dropdown para `EstadoReporte` (Pendiente, En Revisión, etc.)
  - Selector de colonia (lista de colonias únicas extraídas de los reportes existentes)
  - DateRangePicker para rango de fechas
  - Botones "Limpiar filtros" y "Aplicar"
- **NUEVO** `lib/models/filtros_reporte.dart` — Clase inmutable `FiltrosReporte` con campos: categoría?, estado?, colonia?, fechaDesde?, fechaHasta?
- `lib/providers/providers.dart` — Agregar `filtrosReportesProvider` (StateProvider<FiltrosReporte>) + modificar `todosReportesProvider` para aplicar filtros
- `lib/screens/feed_comunitario_screen.dart` — Agregar icono de filtro en AppBar, badge si hay filtros activos, abrir el bottom sheet
- `lib/repositories/reportes_repository.dart` — Opción A: filtrar en query Supabase (`.eq('categoria', ...)`, `.gte('created_at', ...)`). Opción B: mantener filtrado local. **Recomendación: filtrado local** para aprovechar caché y offline  

**Patrón a seguir:** `comentarios_bottom_sheet.dart` para la estructura del BottomSheet

---

## Fase 2 — Cambios de esquema medio

### Step 3: Seguimiento de Tiempos / SLA (*depende de: nada*)
**Objetivo:** Mostrar timeline de cambios de estado y tiempo estimado de resolución en el detalle del reporte.

**DB (SQL en Supabase):**
- Nueva tabla:
  ```
  CREATE TABLE public.historial_estados (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE NOT NULL,
    estado_anterior estado_reporte,
    estado_nuevo estado_reporte NOT NULL,
    cambiado_por UUID REFERENCES public.perfiles_usuarios(id),
    comentario TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
  );
  ALTER TABLE public.historial_estados ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Ver historial de reportes" ON public.historial_estados FOR SELECT USING (true);
  ```
- Trigger automático en `reportes` para registrar cambios de estado:
  ```
  CREATE OR REPLACE FUNCTION registrar_cambio_estado()
  RETURNS TRIGGER AS $$
  BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
      INSERT INTO public.historial_estados (reporte_id, estado_anterior, estado_nuevo, cambiado_por)
      VALUES (NEW.id, OLD.estado, NEW.estado, auth.uid());
    END IF;
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

  CREATE TRIGGER trg_historial_estado
  AFTER UPDATE ON public.reportes
  FOR EACH ROW EXECUTE FUNCTION registrar_cambio_estado();
  ```
- Opcional: agregar columna `sla_horas INTEGER DEFAULT 72` en `reportes` (o valor global en config)

**App — archivos a modificar/crear:**
- **NUEVO** `lib/models/historial_estado.dart` — Modelo con estadoAnterior, estadoNuevo, cambiadoPor, comentario, createdAt
- `lib/repositories/reportes_repository.dart` — Método `obtenerHistorialEstados(reporteId)` → SELECT con order by created_at
- **NUEVO** `lib/widgets/timeline_estados_widget.dart` — Widget vertical tipo timeline (círculos + líneas conectoras) mostrando cada cambio con fecha/hora relativa
- `lib/screens/reporte_detalle_screen.dart` — Insertar `TimelineEstadosWidget` entre la info del reporte y los botones de acción
- Opcional: Mostrar indicador de SLA (barra de progreso o texto "Resuelto en X horas" / "Pendiente hace X horas")

**Patrón a seguir:** Estilo visual similar a los badges de estado que ya usan `EstadoReporte` con colores en `reporte_detalle_screen.dart`

---

### Step 4: Recuperación de Acceso por Email (*depende de: nada, paralelo con step 3*)
**Objetivo:** Permitir login alternativo por email si el SMS falla o el usuario cambió de número.

**DB (SQL en Supabase):**
- Agregar columna opcional email:
  ```
  ALTER TABLE public.perfiles_usuarios ADD COLUMN email VARCHAR(255);
  ```
- Política UPDATE ya agregada en step 1 cubre este campo

**Configuración Supabase Dashboard:**
- En Authentication > Providers: habilitar "Email" con Magic Link (sin contraseña, consistente con OTP actual)
- Configurar plantilla de email en español

**App — archivos a modificar/crear:**
- `lib/models/perfil_usuario.dart` — Agregar campo `email` (String?) al modelo y fromJson/toJson
- `lib/repositories/auth_repository.dart` — Agregar:
  - `enviarMagicLink(String email)` → `_client.auth.signInWithOtp(email: email)`
  - Guardar email opcional durante `consolidarRegistro()`
- `lib/screens/perfil_edit_screen.dart` — Agregar campo email (opcional) al formulario de edición (step 1)
- **NUEVO** `lib/screens/recuperacion_screen.dart` — Pantalla con campo email + botón "Enviar enlace de acceso", mensaje de éxito
- `lib/screens/welcome_screen.dart` o `phone_input_screen.dart` — Agregar link "¿No puedes recibir SMS? Recupera acceso por correo"
- `lib/router/app_router.dart` — Agregar ruta `/recuperacion` (pública)

**Patrón a seguir:** `phone_input_screen.dart` para el diseño del formulario de email

---

## Fase 3 — Features de alta complejidad

### Step 5: Foro Comunitario Ampliado (*depende de: step 2 parcialmente para reusar patrón de filtros*)
**Objetivo:** Permitir publicar temas de discusión (propuestas, preguntas) además de reportes de incidencias.

**DB (SQL en Supabase):**
- Nuevo enum:
  ```
  CREATE TYPE categoria_tema AS ENUM ('Propuesta', 'Pregunta', 'Discusion', 'Anuncio');
  ```
- Nueva tabla:
  ```
  CREATE TABLE public.temas_foro (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    categoria categoria_tema NOT NULL,
    contenido TEXT NOT NULL,
    votos_apoyo INTEGER DEFAULT 0,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
  );
  ```
- Nueva tabla de comentarios de foro:
  ```
  CREATE TABLE public.comentarios_foro (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tema_id UUID REFERENCES public.temas_foro(id) ON DELETE CASCADE NOT NULL,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    comentario TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
  );
  ```
- Nueva tabla de votos de foro:
  ```
  CREATE TABLE public.votos_foro (
    tema_id UUID REFERENCES public.temas_foro(id) ON DELETE CASCADE NOT NULL,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (tema_id, usuario_id)
  );
  ```
- RLS para las 3 tablas: SELECT público, INSERT/DELETE por usuario autenticado propio
- Trigger `update_modified_column()` ya existente, reutilizar en `temas_foro`

**App — archivos a crear:**
- **NUEVO** `lib/models/tema_foro.dart` — Modelo TemaForo (id, usuarioId, titulo, categoria, contenido, votosApoyo, activo, createdAt, nombreAutor, conteoVotos, usuarioHaVotado, conteoComentarios)
- **NUEVO** `lib/repositories/foro_repository.dart` — CRUD completo: obtenerTemas(), crearTema(), eliminarTema(), toggleVotoForo(), obtenerComentariosForo(), agregarComentarioForo()
- **NUEVO** `lib/screens/foro_screen.dart` — Feed de temas con tabs por categoría (Todos, Propuestas, Preguntas, Discusiones), tarjetas similares a _PostCard
- **NUEVO** `lib/screens/tema_detalle_screen.dart` — Detalle del tema con contenido completo, votos y comentarios
- **NUEVO** `lib/screens/crear_tema_screen.dart` — Formulario: título, categoría (dropdown), contenido (textarea)
- **NUEVO** `lib/widgets/tema_card.dart` — Card reutilizable para temas del foro
- `lib/providers/providers.dart` — Agregar foroRepositoryProvider, temasForoProvider, etc.
- `lib/router/app_router.dart` — Rutas: /foro, /foro/crear, /foro/detalle

**Navegación — 2 opciones:**
- Opción A: Agregar tab "Foro" al NavigationBar de MainScaffold (4 tabs: Inicio, Comunidad, Foro, Perfil)
- Opción B: Integrar como tercer tab dentro de FeedComunitarioScreen ("Reportes" | "Mis Reportes" | "Foro")
- **Recomendación: Opción A** — separación clara de propósito

**Patrón a seguir:** Clonar estructura de `feed_comunitario_screen.dart` + `_PostCard` como template

---

### Step 6: Notificaciones Push con Firebase Cloud Messaging (*depende de: step 3 para notificar cambios de estado*)
**Objetivo:** Notificaciones push reales para cambios de estado de reportes y alertas urgentes.

**Firebase Setup (previo):**
1. Crear proyecto Firebase en console.firebase.google.com
2. Registrar app Android: com.example.comunidad_bochil (verificar applicationId en android/app/build.gradle.kts)
3. Descargar google-services.json → android/app/
4. Registrar app iOS (si aplica): descargar GoogleService-Info.plist → ios/Runner/
5. En android/build.gradle.kts: agregar plugin `com.google.gms.google-services`
6. En android/app/build.gradle.kts: aplicar plugin + dependencia

**DB (SQL en Supabase):**
- Nueva tabla:
  ```
  CREATE TABLE public.device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    token TEXT NOT NULL,
    plataforma VARCHAR(10) NOT NULL, -- 'android', 'ios'
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(usuario_id, token)
  );
  ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Gestionar tokens propios" ON public.device_tokens
  FOR ALL USING (auth.uid() = usuario_id) WITH CHECK (auth.uid() = usuario_id);
  ```

**Backend — Supabase Edge Function (Deno/TypeScript):**
- **NUEVO** `supabase/functions/enviar-push/index.ts` — Edge Function que:
  1. Recibe payload del webhook (reporte_id, estado_nuevo)
  2. Busca device_tokens del usuario_id dueño del reporte
  3. Llama a FCM API v1 con el token
  4. Mensajes: "Tu reporte '{titulo}' cambió a {estado_nuevo}"
- **Webhook en Supabase Dashboard:** Database Webhook en tabla `historial_estados` → INSERT → llama Edge Function
- **Para alertas:** Segundo webhook en `alertas_oficiales` → INSERT → envía push a TODOS los tokens

**App — archivos a modificar/crear:**
- `pubspec.yaml` — Agregar `firebase_core`, `firebase_messaging`
- `lib/main.dart` — Inicializar Firebase antes de runApp
- **NUEVO** `lib/services/push_notification_service.dart` — Servicio singleton:
  - Solicitar permisos de notificación
  - Obtener FCM token
  - Guardar/actualizar token en tabla `device_tokens`
  - Listener de token refresh
  - Handler de notificación en foreground (mostrar snackbar o dialog)
  - Handler de tap en notificación (navegar al reporte)
- `lib/screens/main_scaffold.dart` — Inicializar push_notification_service en initState
- `lib/repositories/auth_repository.dart` — Al hacer cerrarSesion(), eliminar token del device

**Patrón a seguir:** `SyncService` como referencia de servicio singleton que se inicializa en MainScaffold

---

## Archivos relevantes (resumen)

### Existentes a modificar
- `lib/repositories/auth_repository.dart` — Steps 1, 4, 6
- `lib/repositories/reportes_repository.dart` — Steps 2, 3
- `lib/screens/perfil_screen.dart` — Step 1
- `lib/screens/feed_comunitario_screen.dart` — Step 2
- `lib/screens/reporte_detalle_screen.dart` — Step 3
- `lib/screens/welcome_screen.dart` o `phone_input_screen.dart` — Step 4
- `lib/screens/main_scaffold.dart` — Steps 5, 6
- `lib/models/perfil_usuario.dart` — Steps 1, 4
- `lib/models/reporte.dart` — Referencia para nuevos modelos
- `lib/providers/providers.dart` — Steps 1, 2, 3, 5, 6
- `lib/router/app_router.dart` — Steps 1, 4, 5
- `lib/core/constants.dart` — Step 5 (nuevos enums de categoría foro)
- `lib/main.dart` — Step 6
- `pubspec.yaml` — Step 6
- `docs/BASE_DE_DATOS_TABLES.md` — Steps 1, 3, 4, 5, 6

### Nuevos a crear
- `lib/screens/perfil_edit_screen.dart` — Step 1
- `lib/widgets/filtros_reportes_sheet.dart` — Step 2
- `lib/models/filtros_reporte.dart` — Step 2
- `lib/models/historial_estado.dart` — Step 3
- `lib/widgets/timeline_estados_widget.dart` — Step 3
- `lib/screens/recuperacion_screen.dart` — Step 4
- `lib/models/tema_foro.dart` — Step 5
- `lib/repositories/foro_repository.dart` — Step 5
- `lib/screens/foro_screen.dart` — Step 5
- `lib/screens/tema_detalle_screen.dart` — Step 5
- `lib/screens/crear_tema_screen.dart` — Step 5
- `lib/widgets/tema_card.dart` — Step 5
- `lib/services/push_notification_service.dart` — Step 6
- `supabase/functions/enviar-push/index.ts` — Step 6

---

## Verificación

### Por fase
1. **Fase 1:** Filtrar por cada criterio individual y combinado. Verificar que la caché no interfiera con filtros.
2. **Fase 2:** Cambiar estado de un reporte desde Supabase Dashboard → verificar que aparece en timeline en app. Enviar magic link al email registrado → verificar que permite login.
3. **Fase 3:** Crear tema de foro, votar, comentar. Recibir push al cambiar estado de reporte desde dashboard. Push de alerta oficial.

### Comandos de validación
- `flutter analyze` tras cada step
- `flutter build apk --debug` para verificar compilación con Firebase
- Test manual de cada flujo en emulador/dispositivo

### Checklist RLS
- Verificar que UPDATE de perfil solo permite modificar el propio
- Verificar que temas_foro, comentarios_foro, votos_foro respetan autoría
- Verificar que device_tokens solo accesible por usuario propio
- Verificar que historial_estados es lectura pública (transparencia)

---

## Decisiones

- **Foro = tabla nueva** `temas_foro` (no extender `reportes`) — datos diferentes, sin coordenadas
- **Filtros = locales** (no server-side) — aprovecha caché existente y funciona offline
- **Recuperación = Magic Link** por email (sin contraseña) — consistente con OTP actual
- **Push = FCM** con Supabase Edge Functions como backend — la propuesta especifica Firebase
- **Navegación del foro:** Tab separado en NavigationBar (4 tabs)
- **SLA automático:** Trigger en DB para registrar historial sin depender de la app

## Dependencias entre steps
- Steps 2: independientes, **paralelos**
- Steps 3 y 4: independientes entre sí, **paralelos**
- Step 5: puede iniciar tras step 2 (reusar patrón filtros), pero no bloquea
- Step 6: depende de step 3 (historial_estados para trigger de push)
