
### 📋 PROMPT PARA EL AGENTE DE IA: DESARROLLO FASE 1

**Contexto del Proyecto:**
Actúa como un desarrollador Senior en Flutter y Supabase. Estamos construyendo una aplicación móvil para la gestión de agua (SAPAM) en el municipio de Bochil, Chiapas.
La aplicación utilizará **Flutter** para el frontend y **Supabase** (PostgreSQL, Auth, Storage, PostGIS) para el backend.
Esta es la **Fase 1: Flujo del Ciudadano**, que abarca desde el escaneo de un código QR de invitación, autenticación OTP por SMS, hasta la creación de un reporte georreferenciado con fotografías.

#### 1. Configuración Inicial y Dependencias (`pubspec.yaml`)

Por favor, configura el proyecto instalando las siguientes dependencias clave:

* `supabase_flutter`: Para la conexión con la base de datos, Auth y Storage.
* `mobile_scanner`: Para leer el código QR físico provisto por el Ayuntamiento.
* `geolocator`: Para obtener la ubicación actual del usuario mediante el GPS del dispositivo.
* `flutter_map` y `latlong2`: Para visualizar el mapa usando OpenStreetMap (gratuito, según requerimientos).
* `image_picker`: Para tomar la foto de la evidencia de la fuga.
* `flutter_riverpod` (o el gestor de estado de tu preferencia): Para manejar el estado de la aplicación.
* `go_router`: Para la navegación y protección de rutas (redirección si no está logueado).

#### 2. Estructura de Base de Datos (Contexto para el Agente)

*El backend ya está configurado. Aquí tienes la estructura para generar los Modelos (Data Classes) en Dart:*

* **Tabla `invitaciones_qr**`: `id` (UUID), `numero_contrato` (String), `usado` (Boolean).
* **Tabla `perfiles_usuarios**`: `id` (UUID - Auth), `rol` (String: 'ciudadano'), `nombre_completo`, `colonia`, `telefono`.
* **Tabla `reportes**`: `id` (UUID), `usuario_id` (UUID), `titulo`, `categoria` (Enum: Fuga, Sin Agua, etc.), `descripcion`, `ubicacion` (PostGIS Geography POINT), `fotos_urls` (List<String>), `estado` (String).

#### 3. Tarea 1: Flujo de Registro Seguro (QR + OTP)

Implementa el siguiente flujo paso a paso:

1. **Pantalla de Escaneo (`ScannerScreen`):** Usa `mobile_scanner`. Al detectar un UUID en el QR, pausa el escáner y consulta a Supabase: `supabase.from('invitaciones_qr').select().eq('id', qr_uuid).single()`. Valida que `usado == false`.
2. **Pantalla de Reto de Seguridad:** Solicita al usuario que ingrese su `numero_contrato`. Valida en local que coincida con el dato traído del QR. Si es correcto, avanza.
3. **Pantalla de Teléfono (`PhoneInputScreen`):** Pide el número de celular. Llama a `supabase.auth.signInWithOtp(phone: numero)`.
4. **Pantalla de Verificación (`OtpVerifyScreen`):** Pide el código de 6 dígitos. Llama a `supabase.auth.verifyOTP()`.
5. **Lógica de Consolidación:** Una vez autenticado, ejecuta una transacción (o llamadas secuenciales) para:
* Insertar los datos del QR en `perfiles_usuarios` usando el `supabase.auth.currentUser!.id`.
* Actualizar `invitaciones_qr` seteando `usado = true`.



#### 4. Tarea 2: Pantalla Principal y Mapa de Reportes (`HomeScreen`)

1. Crea un mapa interactivo usando `flutter_map` y OpenStreetMap.
2. Centra el mapa inicialmente en las coordenadas generales de Bochil, Chiapas (o usando el GPS del dispositivo si tiene permiso).
3. Consulta la tabla `reportes` y dibuja marcadores (Pins) en el mapa para los reportes existentes. *Nota PostGIS:* Extrae las coordenadas de la columna `ubicacion`.
4. Agrega un *Floating Action Button* (FAB) grande que diga "Reportar Problema".

#### 5. Tarea 3: Flujo Híbrido de Geolocalización (`LocationPickerScreen`)

Cuando el usuario presiona "Reportar Problema":

1. Usa `geolocator` para obtener la latitud y longitud actual.
2. Muestra un mapa de pantalla completa centrado en esa ubicación.
3. **Crucial:** Coloca un ícono de Marcador estático en el *centro exacto de la pantalla* (sobre el mapa, no dentro del mapa).
4. Permite al usuario arrastrar el mapa. Utiliza el controlador del mapa para obtener la coordenada central (`mapController.camera.center`) al momento de presionar el botón "Confirmar Ubicación".

#### 6. Tarea 4: Formulario de Reporte y Subida de Evidencia (`ReportFormScreen`)

1. Muestra un formulario con:
* `DropdownButton` para Categoría (Fuga, Sin Agua, Baja Presión, etc.).
* `TextField` multilinea para la Descripción.
* Botón "Tomar Foto".


2. Usa `image_picker` para abrir la cámara. Muestra una miniatura de la foto tomada.
3. **Lógica de Subida (Submit):**
* Paso A: Sube el archivo de imagen al *Storage* de Supabase en el bucket `evidencia_reportes` usando `supabase.storage.from('evidencia_reportes').upload()`. Obtén la URL pública.
* Paso B: Inserta el registro en la tabla `reportes`.
* *Atención a la sintaxis PostGIS para el agente:* Para insertar la `ubicacion`, como la base de datos usa PostGIS `geography(POINT, 4326)`, el payload en Dart debe enviarse construyendo el punto así: `'ubicacion': 'POINT(${lon} ${lat})'`.



#### 7. Reglas de Estilo y Código

* Separa la UI de la lógica de negocio (usa patrón Repository o Notifiers de Riverpod).
* Maneja los errores con `try-catch` y muestra `SnackBars` amigables al usuario (ej. "Código QR inválido" o "No hay conexión a internet").
* Usa los colores institucionales (proporciónalos si los tienes, ej. Azul SAPAM).

---

> **"A continuación te proporciono el script SQL exacto que ya ejecuté en mi backend de Supabase. Úsalo ÚNICAMENTE como contexto para entender el esquema, los nombres de las tablas, los tipos de datos (Enums) y las relaciones. Basado en esto, genera los Modelos de datos en Dart con sus métodos `fromJson` y `toJson`:"**
>

-- ==============================================================================
-- 1. EXTENSIONES NECESARIAS
-- ==============================================================================
-- Activa PostGIS para el manejo de mapas y geolocalización de las fugas
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==============================================================================
-- 2. TIPOS DE DATOS (ENUMS)
-- ==============================================================================
-- Definimos los roles exactos que usarán la app y la plataforma web
CREATE TYPE rol_usuario AS ENUM ('ciudadano', 'tecnico', 'coordinador', 'admin');

-- Categorías de los problemas de agua
CREATE TYPE categoria_reporte AS ENUM ('Fuga', 'Sin Agua', 'Baja Presion', 'Contaminacion', 'Infraestructura');

-- El ciclo de vida de un reporte
CREATE TYPE estado_reporte AS ENUM ('Pendiente', 'En Revision', 'En Progreso', 'Resuelto');


-- ==============================================================================
-- 3. CREACIÓN DE TABLAS
-- ==============================================================================

-- A. TABLA: INVITACIONES QR (Generadas por SAPAM)
CREATE TABLE public.invitaciones_qr (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, 
    curp VARCHAR(18) UNIQUE NOT NULL,
    numero_contrato VARCHAR(50) NOT NULL,
    nombre_titular VARCHAR(150) NOT NULL,
    direccion TEXT NOT NULL,
    colonia VARCHAR(100) NOT NULL,
    
    usado BOOLEAN DEFAULT FALSE NOT NULL,
    usado_por UUID, -- Se llenará con el ID del ciudadano cuando se registre
    fecha_uso TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- B. TABLA: PERFILES DE USUARIOS (Identidad en la plataforma)
CREATE TABLE public.perfiles_usuarios (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    rol rol_usuario DEFAULT 'ciudadano' NOT NULL,
    
    nombre_completo VARCHAR(150) NOT NULL,
    curp VARCHAR(18) UNIQUE NOT NULL,
    numero_contrato VARCHAR(50),
    direccion TEXT,
    colonia VARCHAR(100),
    telefono VARCHAR(20) UNIQUE NOT NULL,
    
    invitacion_id UUID REFERENCES public.invitaciones_qr(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- C. TABLA: REPORTES (El corazón del sistema)
CREATE TABLE public.reportes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    
    -- El técnico al que el coordinador le asigna la reparación
    asignado_a UUID REFERENCES public.perfiles_usuarios(id), 
    
    titulo VARCHAR(150) NOT NULL,
    categoria categoria_reporte NOT NULL,
    descripcion TEXT NOT NULL,
    colonia VARCHAR(100) NOT NULL,
    
    -- Coordenada exacta GPS (PostGIS)
    ubicacion geography(POINT, 4326) NOT NULL,
    
    -- Arreglo para guardar múltiples URLs de fotos de evidencia
    fotos_urls TEXT[] DEFAULT '{}',
    
    estado estado_reporte DEFAULT 'Pendiente',
    votos_apoyo INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- ==============================================================================
-- 4. CONFIGURACIÓN DEL STORAGE (Almacenamiento de Fotos)
-- ==============================================================================
-- Creamos el "Bucket" (Carpeta) para las fotos automáticamente, y lo hacemos público
INSERT INTO storage.buckets (id, name, public) 
VALUES ('evidencia_reportes', 'evidencia_reportes', true) 
ON CONFLICT (id) DO NOTHING;


-- ==============================================================================
-- 5. SEGURIDAD A NIVEL DE FILA (RLS) - POLÍTICAS DE ACCESO
-- ==============================================================================
-- Activamos RLS en todas las tablas
ALTER TABLE public.invitaciones_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reportes ENABLE ROW LEVEL SECURITY;

-- REGLAS PARA INVITACIONES QR
-- 1. Cualquiera puede validar si un código existe y no ha sido usado
CREATE POLICY "Permitir leer invitaciones válidas" ON public.invitaciones_qr 
FOR SELECT USING (usado = false);

-- 2. El usuario que se acaba de registrar puede marcar el QR como usado
CREATE POLICY "Permitir marcar QR como usado al registrarse" ON public.invitaciones_qr 
FOR UPDATE USING (auth.role() = 'authenticated');

-- REGLAS PARA PERFILES
-- 1. Un usuario solo puede ver su propio perfil
CREATE POLICY "Ver perfil propio" ON public.perfiles_usuarios 
FOR SELECT USING (auth.uid() = id);

-- 2. Permitir insertar el perfil al momento del registro
CREATE POLICY "Insertar perfil propio" ON public.perfiles_usuarios 
FOR INSERT WITH CHECK (auth.uid() = id);

-- REGLAS PARA REPORTES
-- 1. Todos pueden leer los reportes (para que funcione el mapa de la app y web)
CREATE POLICY "Reportes visibles para todos" ON public.reportes 
FOR SELECT USING (true);

-- 2. Solo usuarios logueados pueden crear un reporte a su nombre
CREATE POLICY "Crear reporte propio" ON public.reportes 
FOR INSERT WITH CHECK (auth.uid() = usuario_id);

-- 3. Los ciudadanos pueden editar sus propios reportes (ej. añadir info)
CREATE POLICY "Editar reporte propio" ON public.reportes 
FOR UPDATE USING (auth.uid() = usuario_id);

-- REGLAS PARA STORAGE (FOTOS)
-- 1. Cualquiera puede ver las fotos de las fugas
CREATE POLICY "Ver fotos publicas" ON storage.objects 
FOR SELECT USING (bucket_id = 'evidencia_reportes');

-- 2. Solo usuarios logueados pueden subir fotos desde la app
CREATE POLICY "Subir fotos autenticado" ON storage.objects 
FOR INSERT WITH CHECK (bucket_id = 'evidencia_reportes' AND auth.role() = 'authenticated');


-- ==============================================================================
-- 6. AUTOMATIZACIÓN (TRIGGERS)
-- ==============================================================================
-- Esta función actualiza automáticamente la columna 'updated_at' cada vez que el SAPAM 
-- cambia el estado de un reporte (ej. de Pendiente a Resuelto).
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_reportes_modtime
BEFORE UPDATE ON public.reportes
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();


-- Borramos las políticas estrictas anteriores
DROP POLICY IF EXISTS "Permitir leer invitaciones válidas" ON public.invitaciones_qr;
DROP POLICY IF EXISTS "Permitir marcar QR como usado al registrarse" ON public.invitaciones_qr;

-- 1. Permitimos que la app lea las invitaciones (evita el error al actualizar)
CREATE POLICY "Permitir leer invitaciones" ON public.invitaciones_qr 
FOR SELECT USING (true);

-- 2. Aseguramos que cualquier usuario recién autenticado pueda actualizar su QR
CREATE POLICY "Permitir marcar QR como usado al registrarse" ON public.invitaciones_qr 
FOR UPDATE USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

ALTER TABLE public.reportes 
ADD COLUMN latitud FLOAT GENERATED ALWAYS AS (ST_Y(ubicacion::geometry)) STORED;

ALTER TABLE public.reportes 
ADD COLUMN longitud FLOAT GENERATED ALWAYS AS (ST_X(ubicacion::geometry)) STORED;