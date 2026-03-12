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

-- 1. Agregamos la columna de privacidad a los reportes
ALTER TABLE public.reportes ADD COLUMN es_publico BOOLEAN DEFAULT true;

-- 2. Creamos la tabla de Votos para evitar votos duplicados
CREATE TABLE public.votos_reportes (
    reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (reporte_id, usuario_id) -- Garantiza 1 voto por persona por reporte
);

-- 3. Activamos seguridad para los votos
ALTER TABLE public.votos_reportes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos ven los votos" ON public.votos_reportes FOR SELECT USING (true);
CREATE POLICY "Usuarios pueden votar" ON public.votos_reportes FOR INSERT WITH CHECK (auth.uid() = usuario_id);
CREATE POLICY "Usuarios pueden quitar su voto" ON public.votos_reportes FOR DELETE USING (auth.uid() = usuario_id);

-- 1. Creamos la tabla de comentarios (usamos IF NOT EXISTS para evitar errores)
CREATE TABLE IF NOT EXISTS public.comentarios_reportes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporte_id UUID REFERENCES public.reportes(id) ON DELETE CASCADE NOT NULL,
    usuario_id UUID REFERENCES public.perfiles_usuarios(id) ON DELETE CASCADE NOT NULL,
    comentario TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Aseguramos que el RLS esté activo en los comentarios
ALTER TABLE public.comentarios_reportes ENABLE ROW LEVEL SECURITY;

-- 3. Limpiamos cualquier política de comentarios previa para evitar duplicados
DROP POLICY IF EXISTS "Ver comentarios" ON public.comentarios_reportes;
DROP POLICY IF EXISTS "Crear comentario" ON public.comentarios_reportes;

-- 4. Creamos las políticas correctas para los comentarios
CREATE POLICY "Ver comentarios" ON public.comentarios_reportes FOR SELECT USING (true);
CREATE POLICY "Crear comentario" ON public.comentarios_reportes FOR INSERT WITH CHECK ((select auth.uid()) = usuario_id);

-- (Nota: No tocamos la tabla de 'votos_reportes' porque tu base de datos 
-- ya la tiene creada correctamente junto con sus reglas de seguridad).

CREATE POLICY "Eliminar reporte propio" 
  ON public.reportes 
  FOR DELETE 
  USING (auth.uid() = usuario_id);