-- ============================================================================
-- SAPAM Bochil - Migracion Step 3 + Step 4 + Step 6
-- Incluye:
-- 1) historial_estados + trigger de cambios de estado
-- 2) columna email en perfiles_usuarios
-- 3) tabla device_tokens para FCM
--
-- Nota Push (FCM v1):
-- Esta migracion no requiere FCM_SERVER_KEY (API heredada).
-- La Edge Function usa FCM HTTP v1 con FIREBASE_SERVICE_ACCOUNT_JSON.
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
