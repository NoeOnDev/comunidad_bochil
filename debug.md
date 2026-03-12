
---

### 📋 PROMPT PARA EL AGENTE DE IA: MEJORAS DE UX/UI Y MULTIMEDIA

**Contexto:**
Actúa como un Experto en UX/UI y Desarrollador Senior en Flutter. Tenemos 3 pantallas básicas (`Nuevo Reporte`, `Mis Reportes` y `Mi Perfil`) conectadas a Supabase. Necesito refactorizarlas para llevar la experiencia del usuario a un nivel profesional, implementando las siguientes mejoras arquitectónicas y visuales.

La tabla `reportes` en Supabase tiene el campo `fotos_urls TEXT[]` (arreglo de strings). La tabla `perfiles_usuarios` tiene `nombre_completo`, `colonia` y `telefono`.

Por favor, implementa los siguientes requerimientos, divididos por pantalla:

#### 1. Pantalla "Nuevo Reporte" (Mejora Multimedia)

* **Selección Múltiple:** Reemplaza la captura de una sola foto por un sistema que permita subir hasta **3 fotografías**.
* **Opciones de Origen:** Al presionar "Agregar Foto", muestra un `BottomSheet` o `Dialog` que le pregunte al usuario: "Tomar Foto (Cámara)" o "Elegir de la Galería". Usa el paquete `image_picker`.
* **UI de Vista Previa:** Muestra las fotos seleccionadas en un `Wrap` o `ListView` horizontal usando miniaturas pequeñas. Cada miniatura debe tener un botón con una "X" en la esquina superior derecha para poder eliminarla antes de enviar el reporte.
* **Lógica de Subida (Supabase Storage):** Al presionar "Enviar Reporte", itera sobre la lista de imágenes seleccionadas, súbelas al bucket `evidencia_reportes` de Supabase, obtén sus URLs públicas y guárdalas en una lista de Strings (`List<String>`). Pasa esa lista al campo `fotos_urls` en el `.insert()` de la base de datos. Muestra un indicador de carga (`CircularProgressIndicator`) mientras se suben, ya que tomará unos segundos.

#### 2. Pantalla "Mis Reportes" (UI de Lista)

* **Mejora de la Tarjeta (Card/ListTile):** Refactoriza el diseño del elemento de la lista.
* **Leading (Izquierda):** Muestra una miniatura (Thumbnail) de la primera imagen del arreglo `fotos_urls`. Si el arreglo está vacío, muestra un icono por defecto (`Icons.water_drop` o `Icons.image_not_supported`). Usa `ClipRRect` para redondear los bordes de la imagen.
* **Trailing (Derecha - Estatus):** Crea un "Badge" (Chip) para el estatus. Dale un color de fondo dinámico (Ej. Naranja suave para "Pendiente", Azul para "En Progreso", Verde para "Resuelto").


* **Navegación al Detalle:** Al hacer `onTap` en la tarjeta, navega a una nueva pantalla llamada `ReporteDetalleScreen`.

#### 3. Nueva Pantalla "ReporteDetalleScreen"

* Crea esta pantalla para mostrar la vista expandida del reporte seleccionado.
* **Contenido:**
* Un carrusel o cuadrícula con todas las fotos de `fotos_urls`.
* El título grande y la categoría.
* La descripción completa del problema.
* El estatus actual destacado.
* La fecha de creación formateada.
* *(Opcional si es rápido de implementar)*: Un pequeño mapa estático de Leaflet centrado en la latitud y longitud del reporte.



#### 4. Pantalla "Mi Perfil" (Identidad del Usuario)

* Haz una consulta a la tabla `perfiles_usuarios` usando el ID del usuario autenticado (`supabase.auth.currentUser!.id`).
* Muestra un Avatar grande y atractivo (puedes usar la primera letra de su nombre).
* Muestra el `nombre_completo`, `telefono` y `colonia` en un diseño tipo Tarjeta (Card) o con `ListTile`s elegantes (ej. Icono de ubicación + texto de la colonia).
* Mejora el diseño del botón "Cerrar Sesión", haciéndolo un botón outlined de color rojo, posicionado en la parte inferior de la pantalla.

**Reglas de Código:**

* Asegúrate de manejar los estados de carga (Loading) mientras se obtienen los datos de Supabase.
* Usa `CachedNetworkImage` si es posible para las imágenes de internet, para no consumir los datos del usuario cada vez que abre la lista.

---
