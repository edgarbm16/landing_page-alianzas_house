# Landing Page Project

Plataforma de landing pages y panel de administración para captación de prospectos inmobiliarios. Construida con Astro + Supabase.

## Stack

| Capa          | Tecnología                                    |
| ------------- | --------------------------------------------- |
| Framework     | Astro 5 (SSR, Vercel adapter)                 |
| Deploy        | Vercel (`@astrojs/vercel@9`)                  |
| Lenguaje      | TypeScript                                    |
| Base de datos | Supabase (PostgreSQL + Auth + Edge Functions) |
| Email         | Resend API                                    |
| Estilos       | Tailwind CSS v4                               |
| Tipografía    | Inter Variable (`@fontsource-variable/inter`) |

---

## Requisitos previos

- [Node.js](https://nodejs.org/) v18+
- [Docker Desktop](https://www.docker.com/products/docker-desktop) (para desarrollo local con Supabase)
- Supabase CLI v2.90.0+ (incluido como dev dependency, se usa via `npx supabase`)

> **Importante:** La versión mínima del CLI es v2.90.0. Versiones anteriores (ej. v2.76.3) son incompatibles con el nuevo formato de keys `sb_publishable_...` y causan errores 401 en Edge Functions locales.

---

## Instalación de herramientas

### Docker Desktop

Requerido para correr Supabase localmente.

1. Descarga el instalador desde [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
2. Instala y reinicia si se solicita
3. Abre Docker Desktop y espera a que el ícono en la barra de tareas quede estable (no animado)

> **Problema conocido en Windows:** Si el instalador falla con `C:\ProgramData\DockerDesktop must be owned by an elevated account`, abre PowerShell como Administrador y ejecuta:
>
> ```powershell
> Remove-Item -Recurse -Force "C:\ProgramData\DockerDesktop"
> ```
>
> Luego vuelve a correr el instalador.

### Supabase CLI

Ya está incluido como dev dependency. Se activa al correr `npm install`:

```bash
npm install
npx supabase --version  # debe mostrar v2.90.0 o superior
```

---

## Configuración inicial

### 1. Instalar dependencias

```bash
npm install
```

### 2. Variables de entorno

Copia el archivo de ejemplo y completa los valores:

```bash
cp .env.example .env.local
```

**Para desarrollo local** (`.env.local`):

```env
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_KEY=<anon key del supabase start>
RESEND_API_KEY=<tu Resend API key>
```

**Para producción** (`.env`):

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_KEY=<anon key de producción>
RESEND_API_KEY=<tu Resend API key>
```

> Astro carga `.env.local` sobre `.env`, por lo que en desarrollo local siempre se usará la instancia local de Supabase sin tocar las credenciales de producción.

### 3. Variables de entorno para Edge Functions

Las Edge Functions tienen su propio archivo de secrets independiente del `.env.local`:

```bash
grep "RESEND_API_KEY" .env.local > supabase/functions/.env
```

Este archivo **no se commitea** (está en `.gitignore`). En producción, configurar los secrets en Supabase Dashboard → Edge Functions → Manage secrets:

```
RESEND_API_KEY=<tu Resend API key>
SITE_URL=https://<tu-dominio>
```

> `SITE_URL` es requerido para que las Edge Functions restrinjan CORS al dominio de producción. Sin él, CORS cae al fallback de `localhost:4321`.

---

## Desarrollo local con Supabase

### 1. Levantar Supabase local

Asegúrate de que **Docker Desktop esté corriendo**, luego:

```bash
npx supabase start
```

La primera vez descarga las imágenes Docker (~5 min). Al terminar muestra las credenciales locales:

```
API URL:      http://127.0.0.1:54321
Studio URL:   http://127.0.0.1:54323
anon key:     sb_publishable_...
```

Copia el `API URL` y el `anon key` a tu `.env.local`.

### 2. Cargar datos de producción (opcional)

Para trabajar con datos reales en local, haz un dump de producción y aplícalo:

```bash
# Obtener el password de producción: Supabase Dashboard → Project Settings → Database
SUPABASE_DB_PASSWORD=<password> npx supabase db dump --data-only -f supabase/seed.sql

npx supabase db reset
```

`db reset` aplica todas las migraciones y luego carga el `seed.sql` automáticamente.

> **Nota:** Después de cada `db reset`, el usuario admin se recrea con un **UUID nuevo**. La sesión guardada en el browser quedará inválida — hay que cerrar sesión y volver a entrar para obtener un JWT fresco.

### 3. Levantar el servidor de desarrollo

```bash
npm run dev
```

La app corre en `http://localhost:4321`.

### 4. Edge Functions localmente

Las Edge Functions requieren una **terminal separada** con el flag `--no-verify-jwt` y apuntando al archivo de secrets:

```bash
npx supabase functions serve --no-verify-jwt --env-file supabase/functions/.env
```

> **Por qué `--no-verify-jwt`:** El runtime local de Edge Functions es incompatible con el nuevo formato de keys `sb_publishable_...`. Sin este flag, el runtime rechaza todas las peticiones con 401 antes de que el código de la función ejecute. La validación de roles sigue activa dentro del código de cada función. En producción esto no aplica.

### 5. Supabase Studio (GUI de la base de datos local)

Disponible en `http://127.0.0.1:54323` mientras `supabase start` esté activo.

---

## Comandos

### Aplicación

| Comando             | Acción                                       |
| ------------------- | -------------------------------------------- |
| `npm run dev`       | Servidor de desarrollo en `localhost:4321`   |
| `npm run build`     | Build de producción en `./dist/`             |
| `npm run preview`   | Preview del build de producción              |

### Base de datos

| Comando                                  | Acción                                              |
| ---------------------------------------- | --------------------------------------------------- |
| `npx supabase start`                     | Levanta Supabase local (requiere Docker)            |
| `npx supabase stop`                      | Detiene Supabase local                              |
| `npx supabase status`                    | Muestra URLs y keys del entorno local activo        |
| `npx supabase db reset`                  | Resetea la BD local y aplica migraciones + seed     |
| `npx supabase db diff -f <nombre>`       | Genera una migración a partir de cambios en Studio  |
| `npx supabase migration new <nombre>`    | Crea un archivo de migración vacío                  |
| `npx supabase db push --db-url <url>`    | Aplica migraciones pendientes a producción          |

### Edge Functions

| Comando                                                                  | Acción                                        |
| ------------------------------------------------------------------------ | --------------------------------------------- |
| `npx supabase functions serve --no-verify-jwt --env-file supabase/functions/.env` | Sirve las funciones localmente con hot-reload |
| `npx supabase functions deploy <nombre>`                                 | Despliega una función a producción            |

### Sincronización con producción

```bash
# Dump de datos de producción
SUPABASE_DB_PASSWORD=<password> npx supabase db dump --data-only -f supabase/seed.sql

# Aplicar al local
npx supabase db reset
```

---

## Estructura del proyecto

```
/
├── public/                        # Assets estáticos servidos con URL directa
├── src/
│   ├── styles/
│   │   └── global.css             # Tailwind import + estilos base (font, color)
│   ├── components/
│   │   ├── landing/               # Componentes de landing pages
│   │   │   ├── SectionHeader.astro    # Encabezado reutilizable (badge + h2 + subtitle)
│   │   │   ├── LandingNav.astro       # Navbar con logo/nombre desde settings
│   │   │   ├── LandingHero.astro      # Hero de dos columnas con imagen o video
│   │   │   ├── StatsBar.astro         # Barra de estadísticas estática
│   │   │   ├── AboutSection.astro     # Sección "Quiénes somos" con h2 dinámico
│   │   │   ├── ServicesSection.astro  # Tarjetas de servicios
│   │   │   ├── PartnersBar.astro      # Logos de aliados (AMPI, bancos, etc.)
│   │   │   ├── PropertiesSection.astro# Portafolio de propiedades destacadas
│   │   │   ├── TestimonialsSection.astro # Testimonios de clientes
│   │   │   ├── ContactSection.astro   # Contenedor del formulario de contacto
│   │   │   ├── ContactForm.astro      # Formulario con envío a Edge Function
│   │   │   ├── LandingFooter.astro    # Footer con logo/nombre desde settings
│   │   │   └── WhatsAppButton.astro   # Botón flotante de WhatsApp
│   │   └── dashboard/             # Componentes reutilizables del dashboard
│   │       ├── FormField.astro    # Wrapper label + input con hint opcional
│   │       └── SectionCard.astro  # Tarjeta bg-gray-800 con título opcional
│   ├── layouts/
│   │   ├── Layout.astro           # Layout base (carga settings, favicon, GTM, OG tags)
│   │   └── DashboardLayout.astro  # Layout compartido del dashboard (sidebar, navbar, auth, toasts)
│   └── pages/
│       ├── index.astro            # Sirve la landing marcada como is_home=true
│       ├── [slug].astro           # Landings dinámicas por slug
│       ├── gracias.astro          # Confirmación de formulario de contacto
│       ├── aviso-privacidad.astro # Aviso de privacidad (LFPDPPP)
│       ├── robots.txt.ts          # robots.txt dinámico (SSR)
│       ├── login.astro            # Login de administración
│       ├── dashboard.astro        # Panel de administración principal
│       └── dashboard/
│           ├── prospects.astro    # Gestión de prospectos
│           ├── landings.astro     # Gestión de landing pages
│           ├── emails.astro       # Destinatarios de correo
│           ├── users.astro        # Gestión de usuarios
│           └── settings.astro     # Configuración global
├── supabase/
│   ├── config.toml                # Configuración del entorno local
│   ├── migrations/                # Migraciones de BD en orden cronológico
│   ├── functions/                 # Edge Functions (Deno)
│   │   ├── send-contact-email/
│   │   ├── create-admin/
│   │   ├── create-user/
│   │   ├── delete-user/
│   │   ├── update-user-password/  # Cambio de contraseña con validación de jerarquía de roles
│   │   └── .env                   # Secrets locales (no commitear)
│   └── seed.sql                   # Datos de prueba (no commitear)
├── .env                           # Variables de producción (no commitear)
├── .env.local                     # Variables locales (no commitear)
└── .env.example                   # Plantilla de variables (sí commitear)
```

---

## Base de datos

### Tablas principales

| Tabla                    | Descripción                                       |
| ------------------------ | ------------------------------------------------- |
| `prospects`              | Leads capturados por los formularios de contacto  |
| `landings`               | Configuración de cada landing page                |
| `settings`               | Configuración global (logo, empresa, favicon, GTM)|
| `email_recipients`       | Destinatarios de los emails de contacto           |
| `user_profiles`          | Perfil y rol de cada usuario administrador        |
| `module_permissions`     | Permisos granulares por módulo y usuario          |

### Columnas relevantes de `landings`

| Columna                   | Tipo    | Descripción                                              |
| ------------------------- | ------- | -------------------------------------------------------- |
| `slug`                    | text    | Identificador de URL (`dominio.com/{slug}`)              |
| `name`                    | text    | Nombre interno de la landing                             |
| `is_home`                 | boolean | Si `true`, se sirve en `/`. Solo una landing puede serlo |
| `published`               | boolean | Si `false`, la landing no es accesible públicamente      |
| `meta_title`              | text    | Título de pestaña y OG tag (fallback: `name`)            |
| `meta_description`        | text    | Descripción para SEO y OG tag                            |
| `h1`                      | text    | Título principal del hero                                |
| `h2`                      | text    | Título de la sección "Quiénes somos"                     |
| `description`             | text    | Subtítulo del hero                                       |
| `hero_url`                | text    | URL de la imagen o video del hero (también OG image)     |
| `hero_type`               | text    | `image` o `video`                                        |
| `phone`                   | text    | Teléfono mostrado en la navbar                           |
| `whatsapp`                | text    | Número de WhatsApp (formato internacional)               |
| `whatsapp_message`        | text    | Mensaje predefinido al abrir WhatsApp                    |
| `whatsapp_button_enabled` | boolean | Muestra el botón flotante de WhatsApp                    |

### Roles de usuario

La jerarquía es `Administrador (4) > Gestor (3) > Editor (2) > Analista (1)`. Un usuario solo puede crear o modificar usuarios de nivel inferior al suyo. Contraseña mínima: 8 caracteres.

| Rol           | Permisos                                                                      |
| ------------- | ----------------------------------------------------------------------------- |
| Administrador | Acceso total; puede crear/gestionar Gestor, Editor y Analista                 |
| Gestor        | Gestión de prospectos, landings y usuarios; puede crear/gestionar Editor y Analista |
| Editor        | Acceso según permisos de módulo asignados; no puede crear usuarios            |
| Analista      | Solo lectura en los módulos habilitados; no puede crear usuarios              |

### Agregar migraciones

Nunca modifiques las tablas directamente en producción. El flujo correcto es:

1. Modifica el schema en Supabase Studio local (`http://127.0.0.1:54323`)
2. Genera la migración: `npx supabase db diff -f nombre_descriptivo`
3. Revisa el archivo generado en `supabase/migrations/`
4. Aplica en producción:

```bash
npx supabase db push --db-url "postgresql://postgres.<project-ref>:<password>@aws-1-us-east-2.pooler.supabase.com:5432/postgres"
```

> La URL directa (`db.<project-ref>.supabase.co`) no funciona por IPv6. Usar siempre el **Session pooler** (puerto 5432) desde Supabase Dashboard → Settings → Database → Connection string → Session pooler.

---

## Edge Functions

Las funciones serverless están en `supabase/functions/`. Cada función valida el rol del caller antes de ejecutar.

| Función                  | Roles permitidos             | Descripción                                              |
| ------------------------ | ---------------------------- | -------------------------------------------------------- |
| `send-contact-email`     | Público (sin auth)           | Guarda prospecto y envía email via Resend. Límite: 3 envíos por email por hora. |
| `create-admin`           | Administrador                | Crea el usuario administrador inicial                    |
| `create-user`            | Administrador, Gestor        | Crea usuarios con rol inferior al del caller             |
| `delete-user`            | Administrador, Gestor        | Elimina usuario de auth.users (cascade)                  |
| `update-user-password`   | Administrador, Gestor        | Cambia la contraseña de un usuario de menor jerarquía    |

### Cómo llamar Edge Functions desde el frontend

Siempre incluir ambos headers:

```javascript
fetch(`${supabaseUrl}/functions/v1/nombre-funcion`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${session.access_token}`,
    'apikey': supabaseKey,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(payload),
});
```

---

## Dashboard

### DashboardLayout

Todas las páginas del dashboard usan `DashboardLayout.astro` como layout compartido. Acepta tres props:

```astro
<DashboardLayout title="Título pestaña" activeNav="prospects" pageTitle="Título visible">
  <!-- contenido de la página -->
</DashboardLayout>
```

El layout gestiona la autenticación, la visibilidad de ítems del sidebar según rol/permisos, y dispara el evento `dashboard-ready` cuando el usuario está autenticado. Las páginas hijas escuchan este evento para cargar sus datos:

```typescript
window.addEventListener('dashboard-ready', async (e: Event) => {
  const { session, profile } = (e as CustomEvent).detail;
  // cargar datos de la página
});
```

### Sistema de alertas y confirmaciones

El layout inyecta dos funciones globales accesibles desde cualquier página del dashboard:

| Función | Descripción |
| ------- | ----------- |
| `window.dashAlert(message, type)` | Toast no bloqueante en esquina superior derecha. `type`: `'success'` \| `'error'` \| `'info'`. Se auto-descarta a los 3.5s. |
| `window.dashConfirm(message)` | Modal de confirmación. Devuelve `Promise<boolean>`. Reemplaza al `window.confirm()` nativo. |

### Componentes reutilizables (`src/components/dashboard/`)

| Componente | Props | Uso |
| ---------- | ----- | --- |
| `FormField.astro` | `label`, `hint?`, `class?` | Agrupa `<label>` + cualquier input con gap consistente. El contenido va en el slot. |
| `SectionCard.astro` | `title?`, `class?` | Tarjeta `bg-gray-800` con título y borde inferior. El contenido va en el slot. |

### Búsqueda y filtros en Landings

El módulo de landings tiene búsqueda en tiempo real (por nombre o slug) y filtros por estado. El filtrado es completamente en cliente — una sola carga inicial, sin requests adicionales al cambiar filtro o buscar. Los datos se recargan automáticamente después de crear, editar, copiar o eliminar una landing.

### Visibilidad de contraseña

Los campos de contraseña en `/login` y en el modal de usuarios incluyen un botón ojo/ojo-cerrado que alterna el `type` del input entre `password` y `text`.

### Cambio de contraseña propia (Administrador)

Cuando un **Administrador** abre el modal de edición de su propio usuario, aparece un bloque adicional para cambiar su contraseña. Este campo solo es visible para el Administrador editando su propia cuenta — no para otros roles ni al editar a otros usuarios. El cambio se aplica via `supabase.auth.updateUser()` con el JWT activo, sin pasar por Edge Functions.

---

## Estilos y tipografía

Los estilos globales están en `src/styles/global.css`. Usa `@import "tailwindcss"` (Tailwind v4) y define los estilos base del `body` en `@layer base`.

La fuente **Inter Variable** se carga desde el paquete npm `@fontsource-variable/inter`, importado en el frontmatter de `Layout.astro`:

```ts
import '@fontsource-variable/inter/index.css';
```

Vite la incluye en el bundle — no hay petición a Google Fonts ni dependencia de red externa. El archivo cubre todos los pesos (100–900) con una sola variable font.

---

## Settings y configuración global

El módulo de configuración (`/dashboard/settings`) permite cambiar:

- **Nombre de la empresa** — aparece en el título del browser, navbar, footer y template de email
- **Logo** — se muestra en navbar y footer de todas las landings
- **Favicon** — reemplaza el favicon en todas las páginas (no hay favicon estático; se carga siempre desde settings)
- **Google Tag Manager ID** — se inyecta en todas las páginas automáticamente

Estos valores se cargan en `Layout.astro` via Supabase al iniciar cada página y se distribuyen a los componentes mediante el evento `settings-loaded`. El detalle del evento es la fila cruda de Supabase (campos en `snake_case`: `logo_url`, `company_name`, `favicon_url`, etc.).

---

## Landings

### Página principal (`/`)

La ruta raíz sirve la landing marcada con `is_home = true` en la tabla `landings`. Si ninguna landing tiene ese flag activo, devuelve un 404.

Para designar una landing como principal, usar el botón **"Usar como principal"** en el módulo de landings del dashboard. Solo una landing puede ser principal a la vez — la anterior pierde el rol automáticamente.

### Landings por slug (`/{slug}`)

Cada landing publicada es accesible en `dominio.com/{slug}`. Las landings no publicadas devuelven 404.

### Componentes de landing (`src/components/landing/`)

Cada sección de la landing es un componente independiente. `SectionHeader.astro` es un componente base reutilizable por todas las secciones que tienen badge + título + subtítulo.

| Componente | Props dinámicos | Fuente de datos |
| ---------- | --------------- | --------------- |
| `LandingNav` | `phone?` | `settings-loaded` para logo y nombre |
| `LandingHero` | `h1?`, `description?`, `hero_url?`, `hero_type?` | BD (landing) |
| `AboutSection` | `h2?` | BD (landing) |
| `ContactSection` | `landingId?` | BD (landing) |
| `WhatsAppButton` | `whatsapp`, `message?` | BD (landing) |
| `LandingFooter` | — | `settings-loaded` para logo y nombre |
| Resto de secciones | — | Contenido estático |

### Meta tags y Open Graph

Cada landing usa sus propios datos para las meta tags del `<head>`:

- `og:title` / `<title>` → `meta_title` (fallback: `name`)
- `og:description` / `<meta name="description">` → `meta_description`
- `og:image` → `hero_url` (solo cuando `hero_type` no es `video`)
- `og:url` / `<link rel="canonical">` → URL limpia sin parámetros UTM

### Tipos de archivo permitidos en el hero

El campo "Archivo Hero" acepta únicamente los siguientes tipos MIME. Archivos con extensión incorrecta pero tipo MIME no permitido serán rechazados antes del upload:

| Tipo    | Formatos                          |
| ------- | --------------------------------- |
| Imagen  | JPEG, PNG, WebP, GIF, SVG        |
| Video   | MP4, WebM, OGV                   |

### robots.txt (`/robots.txt`)

Ruta SSR dinámica que sirve un `robots.txt` con `Disallow` sobre `/dashboard/` y `/login`. No incluye sitemap (la plataforma es para Google Ads, no SEO orgánico).

---

## Problemas conocidos y soluciones

### 401 en Edge Functions locales

**Causa:** El runtime de Edge Functions es incompatible con el formato de key `sb_publishable_...` de Supabase CLI v2.90.0+.

**Solución:** Servir siempre con el flag `--no-verify-jwt`:
```bash
npx supabase functions serve --no-verify-jwt --env-file supabase/functions/.env
```

### `RESEND_API_KEY not configured` en Edge Function local

**Causa:** Las Edge Functions leen secrets de su propio archivo, no del `.env.local` del proyecto.

**Solución:** Crear `supabase/functions/.env` con la key:
```bash
grep "RESEND_API_KEY" .env.local > supabase/functions/.env
```

### Error 502 en uploads a Supabase Storage

**Causa:** El servicio `supabase_storage` local quedó en estado unhealthy (puede ocurrir al actualizar el CLI o las imágenes Docker).

**Solución:** Reiniciar el stack completo:
```bash
npx supabase stop
npx supabase start
```

Si persiste (duplicate key en migrations internas de Storage), borrar los volúmenes y resetear:
```bash
docker volume ls --filter label=com.supabase.cli.project=landing-page-project -q | xargs docker volume rm
npx supabase start
npx supabase db reset
```

### Sesión inválida después de `db reset`

**Causa:** Cada `db reset` recrea el usuario admin con un UUID nuevo. El JWT guardado en el browser referencia el UUID anterior.

**Solución:** Cerrar sesión manualmente y volver a iniciar sesión para obtener un JWT fresco.

### Usuario eliminado pero sigue apareciendo en auth

**Causa:** El flujo anterior en el dashboard borraba `user_profiles` directamente antes de llamar al Edge Function. Si el Edge Function fallaba, quedaba el usuario en `auth.users` sin perfil.

**Solución aplicada:** El dashboard ahora llama únicamente al Edge Function `delete-user`, que borra de `auth.users`. El perfil se elimina automáticamente por la restricción `ON DELETE CASCADE` de `user_profiles`.

---

## Crear un proyecto para un cliente nuevo

Este repo sirve como base para proyectos de clientes. El flujo correcto es crear un repo independiente por cliente — los cambios en uno no afectan al otro.

### 1. Crear el repo nuevo en GitHub

Crea un repo vacío en GitHub (en tu cuenta o en la del cliente).

### 2. Clonar este proyecto y desconectarlo

```bash
# Clona el repo base localmente
git clone https://github.com/edgarbm16/landing_page nombre-cliente
cd nombre-cliente

# Desconecta del repo original
git remote remove origin

# Conecta al nuevo repo del cliente
git remote add origin https://github.com/tu-cuenta/nombre-cliente
```

### 3. Arrancar con historial limpio

```bash
# Crea una rama huérfana (sin historial anterior)
git checkout --orphan fresh-start
git add .
git commit -m "feat: initial setup"

# Reemplaza master con la rama limpia
git branch -D master
git branch -m master

# Push inicial
git push -u origin master
```

El paso `--orphan` es clave: el nuevo repo arranca con un solo commit inicial, sin ningún historial del proyecto base.

### 4. Configurar las cuentas del cliente

Cada proyecto de cliente debe tener sus propias cuentas:

| Servicio | Dónde crear |
| -------- | ----------- |
| Supabase | [supabase.com](https://supabase.com) — nuevo proyecto |
| Resend   | [resend.com](https://resend.com) — verificar dominio del cliente |
| Netlify  | Cuenta del cliente, conectar al repo de GitHub |

### 5. Variables de entorno

Actualizar `.env` y `supabase/functions/.env` con las credenciales del proyecto Supabase nuevo, y agregar `SITE_URL` en los secrets de las Edge Functions apuntando al dominio del cliente.

### 6. Aplicar migraciones en el nuevo proyecto

```bash
npx supabase link --project-ref <nuevo-project-ref>
npx supabase db push --db-url "postgresql://postgres.<nuevo-project-ref>:<password>@<pooler-host>:5432/postgres"
npx supabase functions deploy
```

---

## Notas importantes

- **`.env`, `.env.local` y `supabase/functions/.env` nunca deben commitearse** — están en `.gitignore`.
- El archivo `supabase/seed.sql` puede contener datos sensibles si se hace dump de producción. Revisarlo antes de commitearlo — también está en `.gitignore`.
- Las migraciones se aplican en orden por timestamp. No renombrar archivos de migración existentes.
- Al hacer `supabase db reset`, la base de datos local se borra completamente y se recrea desde cero con las migraciones y el seed.
- Las variables de entorno en Astro con prefijo `PUBLIC_` son accesibles en el cliente. Las variables sin prefijo (`SUPABASE_URL`, `SUPABASE_KEY`) solo están disponibles en el frontmatter SSR — pasarlas al cliente via atributos `data-*` en el HTML.
- El evento `settings-loaded` lleva la fila cruda de Supabase como `detail`. Usar siempre `snake_case` al leer sus campos (`detail.logo_url`, `detail.company_name`).
