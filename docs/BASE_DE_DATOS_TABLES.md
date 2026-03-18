-- ==============================================================================
-- 1. EXTENSIONES NECESARIAS
-- ==============================================================================
-- Activa PostGIS para el manejo de mapas y geolocalización
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==============================================================================
-- 2. TIPOS DE DATOS (ENUMS)
-- ==============================================================================
CREATE TYPE rol_usuario AS ENUM ('ciudadano', 'tecnico', 'coordinador', 'admin');
CREATE TYPE categoria_reporte AS ENUM ('Fuga', 'Sin Agua', 'Baja Presion', 'Contaminacion', 'Infraestructura');
CREATE TYPE estado_reporte AS ENUM ('Pendiente', 'En Revision', 'En Progreso', 'Resuelto');

-- ==============================================================================
-- 3. CREACIÓN DE TABLAS (En orden de dependencias)
-- ==============================================================================

-- A. INVITACIONES QR
CREATE TABLE public.invitaciones_qr (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, 
    curp VARCHAR(18) UNIQUE NOT NULL,
    numero_contrato VARCHAR(50) NOT NULL,
    nombre_titular VARCHAR(150) NOT NULL,
    direccion TEXT NOT NULL,
    colonia VARCHAR(100) NOT NULL,
    usado BOOLEAN DEFAULT FALSE NOT NULL,
    usado_por UUID,
    fecha_uso TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- B. PERFILES DE USUARIOS
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

-- C. REPORTES (Incluye columnas calculadas de PostGIS y privacidad)
CREATE TABLE public.reportes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    asignado_a UUID REFERENCES public.perfiles_usuarios(id), 
    titulo VARCHAR(150) NOT NULL,
    categoria categoria_reporte NOT NULL,
    descripcion TEXT NOT NULL,
    colonia VARCHAR(100) NOT NULL,
    ubicacion geography(POINT, 4326) NOT NULL,
    latitud FLOAT GENERATED ALWAYS AS (ST_Y(ubicacion::geometry)) STORED,
    longitud FLOAT GENERATED ALWAYS AS (ST_X(ubicacion::geometry)) STORED,
    fotos_urls TEXT[] DEFAULT '{}',
    estado estado_reporte DEFAULT 'Pendiente',
    es_publico BOOLEAN DEFAULT true,
    votos_apoyo INTEGER DEFAULT 0, -- Se mantiene por compatibilidad local, aunque usemos la tabla votos_reportes
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- D. VOTOS (Likes)
CREATE TABLE public.votos_reportes (
    reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE NOT NULL,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (reporte_id, usuario_id)
);

-- E. COMENTARIOS
CREATE TABLE public.comentarios_reportes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE NOT NULL,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    comentario TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- 4. TRIGGERS (Automatización de fechas)
-- ==============================================================================
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

-- ==============================================================================
-- 5. STORAGE (Almacenamiento de Fotos)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('evidencia_reportes', 'evidencia_reportes', true) 
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 6. SEGURIDAD A NIVEL DE FILA (RLS) Y POLÍTICAS DEFINITIVAS
-- ==============================================================================

-- Activar RLS en todas las tablas
ALTER TABLE public.invitaciones_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votos_reportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comentarios_reportes ENABLE ROW LEVEL SECURITY;

-- Políticas: INVITACIONES QR
CREATE POLICY "Permitir leer invitaciones" ON public.invitaciones_qr FOR SELECT USING (true);
CREATE POLICY "Permitir marcar QR como usado al registrarse" ON public.invitaciones_qr FOR UPDATE USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- Políticas: PERFILES DE USUARIOS
CREATE POLICY "Ver perfil propio" ON public.perfiles_usuarios FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Insertar perfil propio" ON public.perfiles_usuarios FOR INSERT WITH CHECK (auth.uid() = id);

-- Políticas: REPORTES
CREATE POLICY "Reportes visibles para todos" ON public.reportes FOR SELECT USING (true);
CREATE POLICY "Crear reporte propio" ON public.reportes FOR INSERT WITH CHECK (auth.uid() = usuario_id);
CREATE POLICY "Editar reporte propio" ON public.reportes FOR UPDATE USING (auth.uid() = usuario_id);

-- Políticas: VOTOS
CREATE POLICY "Todos ven los votos" ON public.votos_reportes FOR SELECT USING (true);
CREATE POLICY "Usuarios pueden votar" ON public.votos_reportes FOR INSERT WITH CHECK (auth.uid() = usuario_id);
CREATE POLICY "Usuarios pueden quitar su voto" ON public.votos_reportes FOR DELETE USING (auth.uid() = usuario_id);

-- Políticas: COMENTARIOS
CREATE POLICY "Ver comentarios" ON public.comentarios_reportes FOR SELECT USING (true);
CREATE POLICY "Crear comentario" ON public.comentarios_reportes FOR INSERT WITH CHECK (auth.uid() = usuario_id);

-- Políticas: STORAGE (Fotos)
CREATE POLICY "Ver fotos publicas" ON storage.objects FOR SELECT USING (bucket_id = 'evidencia_reportes');
CREATE POLICY "Subir fotos autenticado" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'evidencia_reportes' AND auth.role() = 'authenticated');

CREATE TABLE public.alertas_oficiales (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    nivel_urgencia VARCHAR(20) DEFAULT 'informativo', -- 'informativo', 'advertencia', 'critico'
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.alertas_oficiales ENABLE ROW LEVEL SECURITY;
-- Todos los ciudadanos pueden leer las alertas activas
CREATE POLICY "Ver alertas activas" ON public.alertas_oficiales FOR SELECT USING (activa = true);

-- Insertamos una alerta de prueba para que tu app tenga algo que mostrar
INSERT INTO public.alertas_oficiales (titulo, mensaje, nivel_urgencia) 
VALUES ('Mantenimiento Programado', 'El día de mañana habrá corte de agua en la zona Centro por reparación de tubería principal.', 'advertencia');

CREATE POLICY "Eliminar reporte propio" 
  ON public.reportes 
  FOR DELETE 
  USING (auth.uid() = usuario_id);

-- ============================================================================
-- SAPAM Bochil - Migracion Step 3 + Step 4 + Step 6
-- Incluye:
-- 1) historial_estados + trigger de cambios de estado
-- 2) columna email en perfiles_usuarios
-- 3) tabla device_tokens para FCM
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- STEP 4: Columna email en perfiles_usuarios
-- ----------------------------------------------------------------------------
ALTER TABLE public.perfiles_usuarios
  ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Unicidad case-insensitive para email (solo cuando no sea NULL)
CREATE UNIQUE INDEX IF NOT EXISTS perfiles_usuarios_email_unique_idx
  ON public.perfiles_usuarios (LOWER(email))
  WHERE email IS NOT NULL;

-- ----------------------------------------------------------------------------
-- STEP 3: Tabla historial_estados
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.historial_estados (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE NOT NULL,
  estado_anterior estado_reporte,
  estado_nuevo estado_reporte NOT NULL,
  cambiado_por UUID REFERENCES public.perfiles_usuarios(id),
  comentario TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS historial_estados_reporte_id_idx
  ON public.historial_estados (reporte_id);

CREATE INDEX IF NOT EXISTS historial_estados_created_at_idx
  ON public.historial_estados (created_at DESC);

ALTER TABLE public.historial_estados ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'historial_estados'
      AND policyname = 'Ver historial de reportes'
  ) THEN
    CREATE POLICY "Ver historial de reportes"
      ON public.historial_estados
      FOR SELECT
      USING (true);
  END IF;
END $$;

-- Trigger para registrar cambios de estado de reportes
CREATE OR REPLACE FUNCTION public.registrar_cambio_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO public.historial_estados (
      reporte_id,
      estado_anterior,
      estado_nuevo,
      cambiado_por,
      comentario,
      created_at
    )
    VALUES (
      NEW.id,
      OLD.estado,
      NEW.estado,
      auth.uid(),
      NULL,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_estado ON public.reportes;

CREATE TRIGGER trg_historial_estado
AFTER UPDATE ON public.reportes
FOR EACH ROW
EXECUTE FUNCTION public.registrar_cambio_estado();

-- Seed de historial para reportes existentes (opcional recomendado)
INSERT INTO public.historial_estados (reporte_id, estado_anterior, estado_nuevo, cambiado_por, comentario, created_at)
SELECT r.id, NULL, r.estado, NULL, 'Estado inicial migrado', r.created_at
FROM public.reportes r
WHERE NOT EXISTS (
  SELECT 1
  FROM public.historial_estados h
  WHERE h.reporte_id = r.id
);

-- ----------------------------------------------------------------------------
-- STEP 6: Tabla device_tokens para push notifications
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  plataforma VARCHAR(10) NOT NULL CHECK (plataforma IN ('android', 'ios', 'web', 'macos', 'windows', 'linux')),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE (usuario_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_usuario_id_idx
  ON public.device_tokens (usuario_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_tokens'
      AND policyname = 'Ver tokens propios'
  ) THEN
    CREATE POLICY "Ver tokens propios"
      ON public.device_tokens
      FOR SELECT
      USING (auth.uid() = usuario_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_tokens'
      AND policyname = 'Insertar tokens propios'
  ) THEN
    CREATE POLICY "Insertar tokens propios"
      ON public.device_tokens
      FOR INSERT
      WITH CHECK (auth.uid() = usuario_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_tokens'
      AND policyname = 'Actualizar tokens propios'
  ) THEN
    CREATE POLICY "Actualizar tokens propios"
      ON public.device_tokens
      FOR UPDATE
      USING (auth.uid() = usuario_id)
      WITH CHECK (auth.uid() = usuario_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_tokens'
      AND policyname = 'Eliminar tokens propios'
  ) THEN
    CREATE POLICY "Eliminar tokens propios"
      ON public.device_tokens
      FOR DELETE
      USING (auth.uid() = usuario_id);
  END IF;
END $$;

-- Trigger para updated_at
DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON public.device_tokens;

CREATE TRIGGER trg_device_tokens_updated_at
BEFORE UPDATE ON public.device_tokens
FOR EACH ROW
EXECUTE FUNCTION public.update_modified_column();

COMMIT;
