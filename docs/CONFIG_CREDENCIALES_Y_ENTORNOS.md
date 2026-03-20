# Configuracion de Credenciales y Entornos

## 1) Flutter (cliente)

La app ahora requiere variables al compilar:

- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY

Ejemplo para correr en desarrollo:

flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx

Ejemplo para generar APK release:

flutter build apk --release \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx

## 2) Supabase Edge Functions

No subir a Git valores reales de:

- SUPABASE_SERVICE_ROLE_KEY
- FIREBASE_SERVICE_ACCOUNT_JSON

Definirlos como secrets en Supabase:

supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... FIREBASE_SERVICE_ACCOUNT_JSON='...'

## 3) Git

El repositorio ignora ahora:

- .env y .env.* (excepto .env.example)
- android/app/google-services.json
- ios/Runner/GoogleService-Info.plist
- macos/Runner/GoogleService-Info.plist
- keystores y archivos de llaves privadas

Si algun archivo sensible ya estaba trackeado, removerlo del indice sin borrar local:

git rm --cached android/app/google-services.json
