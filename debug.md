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