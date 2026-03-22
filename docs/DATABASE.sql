-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.alertas_calles (
  alerta_id uuid NOT NULL,
  calle_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT alertas_calles_pkey PRIMARY KEY (alerta_id, calle_id),
  CONSTRAINT alertas_calles_alerta_id_fkey FOREIGN KEY (alerta_id) REFERENCES public.alertas_oficiales(id),
  CONSTRAINT alertas_calles_calle_id_fkey FOREIGN KEY (calle_id) REFERENCES public.catalogo_calles(id)
);
CREATE TABLE public.alertas_oficiales (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  titulo character varying NOT NULL,
  mensaje text NOT NULL,
  nivel_urgencia character varying DEFAULT 'informativo'::character varying,
  activa boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  aplica_todas_calles boolean NOT NULL DEFAULT true,
  calles_objetivo ARRAY NOT NULL DEFAULT '{}'::text[],
  CONSTRAINT alertas_oficiales_pkey PRIMARY KEY (id)
);
CREATE TABLE public.catalogo_calles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre_oficial character varying NOT NULL,
  nombre_normalizado character varying NOT NULL UNIQUE,
  activa boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT catalogo_calles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.comentarios_foro (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tema_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  comentario text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT comentarios_foro_pkey PRIMARY KEY (id),
  CONSTRAINT comentarios_foro_tema_id_fkey FOREIGN KEY (tema_id) REFERENCES public.temas_foro(id),
  CONSTRAINT comentarios_foro_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.comentarios_reportes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporte_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  comentario text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT comentarios_reportes_pkey PRIMARY KEY (id),
  CONSTRAINT comentarios_reportes_reporte_id_fkey FOREIGN KEY (reporte_id) REFERENCES public.reportes(id),
  CONSTRAINT comentarios_reportes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.device_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  token text NOT NULL,
  plataforma character varying NOT NULL CHECK (plataforma::text = ANY (ARRAY['android'::character varying, 'ios'::character varying, 'web'::character varying, 'macos'::character varying, 'windows'::character varying, 'linux'::character varying]::text[])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT device_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT device_tokens_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.historial_estados (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporte_id uuid NOT NULL,
  estado_anterior USER-DEFINED,
  estado_nuevo USER-DEFINED NOT NULL,
  cambiado_por uuid,
  comentario text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT historial_estados_pkey PRIMARY KEY (id),
  CONSTRAINT historial_estados_reporte_id_fkey FOREIGN KEY (reporte_id) REFERENCES public.reportes(id),
  CONSTRAINT historial_estados_cambiado_por_fkey FOREIGN KEY (cambiado_por) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.invitaciones_qr (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  curp character varying NOT NULL UNIQUE,
  numero_contrato character varying NOT NULL,
  nombre_titular character varying NOT NULL,
  direccion text NOT NULL,
  colonia character varying NOT NULL,
  usado boolean NOT NULL DEFAULT false,
  usado_por uuid,
  fecha_uso timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  calle_id uuid,
  CONSTRAINT invitaciones_qr_pkey PRIMARY KEY (id),
  CONSTRAINT invitaciones_qr_calle_id_fkey FOREIGN KEY (calle_id) REFERENCES public.catalogo_calles(id)
);
CREATE TABLE public.notificaciones_lecturas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  tipo character varying NOT NULL CHECK (tipo::text = ANY (ARRAY['alerta_oficial'::character varying, 'estado_reporte'::character varying]::text[])),
  origen_id uuid NOT NULL,
  read_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notificaciones_lecturas_pkey PRIMARY KEY (id),
  CONSTRAINT notificaciones_lecturas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.perfiles_usuarios (
  id uuid NOT NULL,
  rol USER-DEFINED NOT NULL DEFAULT 'ciudadano'::rol_usuario,
  nombre_completo character varying NOT NULL,
  curp character varying NOT NULL UNIQUE,
  numero_contrato character varying,
  direccion text,
  colonia character varying,
  telefono character varying NOT NULL UNIQUE,
  invitacion_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  email character varying,
  calle character varying,
  calle_id uuid,
  CONSTRAINT perfiles_usuarios_pkey PRIMARY KEY (id),
  CONSTRAINT perfiles_usuarios_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT perfiles_usuarios_invitacion_id_fkey FOREIGN KEY (invitacion_id) REFERENCES public.invitaciones_qr(id),
  CONSTRAINT perfiles_usuarios_calle_id_fkey FOREIGN KEY (calle_id) REFERENCES public.catalogo_calles(id)
);
CREATE TABLE public.reportes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  asignado_a uuid,
  titulo character varying NOT NULL,
  categoria USER-DEFINED NOT NULL,
  descripcion text NOT NULL,
  colonia character varying NOT NULL,
  ubicacion USER-DEFINED NOT NULL,
  fotos_urls ARRAY DEFAULT '{}'::text[],
  estado USER-DEFINED DEFAULT 'Pendiente'::estado_reporte,
  votos_apoyo integer DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  latitud double precision DEFAULT st_y((ubicacion)::geometry),
  longitud double precision DEFAULT st_x((ubicacion)::geometry),
  es_publico boolean DEFAULT true,
  CONSTRAINT reportes_pkey PRIMARY KEY (id),
  CONSTRAINT reportes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id),
  CONSTRAINT reportes_asignado_a_fkey FOREIGN KEY (asignado_a) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.temas_foro (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  titulo character varying NOT NULL,
  categoria USER-DEFINED NOT NULL,
  contenido text NOT NULL,
  votos_apoyo integer DEFAULT 0,
  activo boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT temas_foro_pkey PRIMARY KEY (id),
  CONSTRAINT temas_foro_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.votos_foro (
  tema_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT votos_foro_pkey PRIMARY KEY (tema_id, usuario_id),
  CONSTRAINT votos_foro_tema_id_fkey FOREIGN KEY (tema_id) REFERENCES public.temas_foro(id),
  CONSTRAINT votos_foro_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);
CREATE TABLE public.votos_reportes (
  reporte_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT votos_reportes_pkey PRIMARY KEY (reporte_id, usuario_id),
  CONSTRAINT votos_reportes_reporte_id_fkey FOREIGN KEY (reporte_id) REFERENCES public.reportes(id),
  CONSTRAINT votos_reportes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles_usuarios(id)
);