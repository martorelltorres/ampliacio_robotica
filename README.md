# Entorno de prácticas — Ampliació de Robòtica (UIB)

Imagen Docker **completa y lista para el aula**: un escritorio Linux con ROS Noetic que se
abre **en el navegador**, con los simuladores de las tres prácticas ya compilados. Funciona
igual en Windows, macOS y Linux.

El profesor la construye **una vez** y la publica; los alumnos solo la descargan.

- **Instalación paso a paso:** [INSTALLACIO.md](INSTALLACIO.md) — guia completa en català,
  amb els tres sistemes operatius.
- **[Guía del alumno](#guía-del-alumno)** — arrancar, trabajar, cerrar.
- **[Guía del profesor](#guía-del-profesor)** — construir, probar, publicar.

---

## Qué lleva dentro

Base `tiryoh/ros-desktop-vnc:noetic` → escritorio MATE por navegador (noVNC), idéntico en
los tres sistemas operativos. Tres stacks, uno por práctica de laboratorio:

### PL0 — Introducció a ROS

Usa `turtlesim` y las herramientas estándar de ROS Noetic (`rqt_graph`, `rqt_plot`, `rosbag`,
`rviz`...), ya incluidas en la imagen base. No necesita nada adicional.

### PL1 — Odometria en robots amb rodes (Kobuki)

| Componente | Qué es |
|---|---|
| `kobuki`, `kobuki_core`, `kobuki_msgs` | Driver ROS del Kobuki (`kobuki_node`, `kobuki_keyop`) |
| `kobuki_desktop` | Modelo simulado en Gazebo, misma interfaz ROS que el robot físico |
| `yocs_cmd_vel_mux`, `yocs_velocity_smoother` | Multiplexado y suavizado de velocidad que usa el driver |

### PL2 — Navegació per estima submarina (COLA2 + Stonefish)

| Componente | Qué es |
|---|---|
| `cola2_lib` | Biblioteca C++ base del SRV (compilada desde fuente) |
| `Stonefish` | Simulador submarino: dinámica con Bullet Physics, sensores y render OpenGL |
| `cola2_msgs`, `cola2_lib_ros` | Mensajes y utilidades ROS de COLA2 |
| `cola2_core` | Control, navegación, seguridad, log, comms y simulación |
| `sparus2_description`, `cola2_sparus2` | Vehículo **SparusII** |
| `girona500_description`, `cola2_girona500` | Vehículo **Girona500** |
| `stonefish_ros`, `cola2_stonefish` | Puente ROS ↔ Stonefish y los escenarios |

Todos los repositorios de fuente (COLA2/Stonefish y Kobuki) van fijados a **commit**, no a
tag, para que dos construcciones separadas en el tiempo den exactamente la misma imagen.

## Estructura del repositorio

```
ampliacio_robotica/
├── docker-compose.yml           # lo que usan los ALUMNOS para arrancar
├── code/                        # ← TU CÓDIGO VA AQUÍ (se guarda en tu ordenador)
│   ├── PL0/                     #   práctica PL0 — Introducció a ROS
│   ├── PL1/                     #   práctica PL1 — Odometria (Kobuki)
│   └── PL2/                     #   práctica PL2 — Navegació per estima (COLA2)
│
├── INSTALLACIO.md                # guia d'instal·lació pas a pas (català)
└── docker/                       # todo lo que construye la imagen        (PROFESOR)
    ├── Dockerfile.ros_base       # receta de la imagen, capas numeradas
    ├── requirements_py38.txt     # deps Python, versiones fijadas
    ├── course_aliases.sh         # atajos → /etc/course_aliases.sh
    ├── course_selftest.sh        # autotest → 'selftest' dentro de la imagen
    └── course_desktop_setup.sh   # arreglos del escritorio, en CADA arranque
```

`code/` es la única carpeta que persiste fuera de la imagen: cada subcarpeta `PL0/`, `PL1/`
y `PL2/` es donde el alumno crea su propio paquete catkin para esa práctica
(`pl0_cognom`, `pl1_cognom`, `pl2_cognom`). Ningún stack trae ya un paquete de curso
horneado: los tres enunciados piden explícitamente que el alumno cree el suyo con
`catkin_create_pkg`.

---

# Guía del alumno

## Lo que necesitas

- **Docker Desktop** (Windows y macOS) o **Docker Engine** (Linux) — <https://docs.docker.com/get-started/get-docker/>
- Un navegador. Nada más: ROS, los simuladores y el escritorio van dentro de la imagen.
- Unos **12 GB de disco libre**.

> **Descárgala en casa y con tiempo.** Treinta descargas simultáneas el primer día de clase
> no acaban bien.

Para la instalación completa paso a paso en los tres sistemas, con capturas de los comandos
exactos, ver **[INSTALLACIO.md](INSTALLACIO.md)**. El resumen:

**Windows:** Docker Desktop con backend **WSL2**. Pon la carpeta de trabajo en una ruta
normal (`C:\Users\tu_usuario\...`), **no** en una unidad de red ni en OneDrive: la carpeta
compartida falla ahí.

**macOS con chip Apple (M1/M2/M3/M4):** en Docker Desktop → *Settings* → *General*, activa
**"Use Rosetta for x86/amd64 emulation"**. Sin eso va mucho más lento. No tienes que editar
ni descomentar nada.

## Arrancar y cerrar el contenedor

Todos los comandos se ejecutan **desde la carpeta `ampliacio_robotica/`**, en la terminal
de tu sistema (PowerShell, Terminal o la que uses).

```bash
docker compose up -d          # arrancar (en segundo plano)
```

Luego abre **<http://localhost:6080>** en el navegador: ahí está el escritorio.

```bash
docker compose down           # cerrar y borrar el contenedor
docker compose stop           # solo pararlo (conserva el estado interno)
docker compose start          # volver a arrancarlo tras un 'stop'
docker compose logs -f        # ver el arranque (Ctrl-C para salir)
docker compose ps             # ¿está corriendo?
```

**`docker compose down` no borra tu código**: lo que hay en `code/` está en tu disco, no
dentro del contenedor. Ver la sección siguiente.

> ### ⚠ No uses `docker run`
>
> Es el error más frecuente. `docker run` **no monta la carpeta compartida**, así que tu
> código no se guarda y desaparece al borrar el contenedor. También se salta el
> `shm_size`, y entonces el navegador del escritorio se cierra solo.
>
> Usa siempre `docker compose up -d`. El fichero `docker-compose.yml` ya se encarga del
> volumen, el puerto, la memoria compartida y la plataforma.
>
> Si ves `port is already allocated`, es que ya tienes un contenedor levantado. Comprueba
> quién ocupa el puerto con `docker ps` y usa el que ya está.

## Cómo se intercambian los ficheros con tu ordenador

Esta es la parte importante y conviene entenderla bien.

```
   TU ORDENADOR                                DENTRO DEL CONTENEDOR
   ────────────                                ─────────────────────
   ampliacio_robotica/code/       <══════>     /home/ubuntu/catkin_ws/src/student
     ├── PL0/                   (sincronizado    ├── PL0/
     ├── PL1/                    al instante,    ├── PL1/
     └── PL2/                    en ambos        └── PL2/
                                  sentidos)
```

- **Todo lo que escribas en `code/` se ve dentro del contenedor**, y al revés. No hay que
  copiar nada: es la misma carpeta vista desde dos sitios.
- **Es lo único que sobrevive.** El resto del sistema de ficheros del contenedor vive
  dentro de la imagen y **se pierde** con `docker compose down`.
- Puedes editar con tu editor de siempre (VS Code, etc.) desde tu ordenador, o con
  VSCodium dentro del escritorio. Da igual: es el mismo fichero.

Dentro del escritorio tienes el enlace **`MY_CODE`** que lleva directo a esa carpeta.

**Ojo con la ruta:** la carpeta aparece en `catkin_ws/src/`**`student`**`/`, no directamente
en `catkin_ws/src/`. Es a propósito: `src/` contiene también los paquetes de Kobuki y COLA2,
y montar tu carpeta encima los taparía todos.

Cada práctica tiene su subcarpeta (`code/PL0/`, `code/PL1/`, `code/PL2/`). Dentro de cada
una creas tu paquete catkin con `catkin_create_pkg` (ver el enunciado de cada práctica) —
catkin encuentra paquetes en cualquier nivel de `src/`, así que no hace falta que estén
directamente bajo `src/`.

> **Linux:** no borres la carpeta `code/`. Si no existe al arrancar, la crea Docker como
> `root` y no podrás escribir en ella. Si te pasa: `sudo chown -R 1000:1000 code`

## Comprueba que todo funciona

Antes de dar por hecho que algo está roto, lanza el autotest. Es el **mismo comando en
Windows, macOS y Linux**:

```bash
docker compose exec ros-dev selftest
```

O, desde una terminal dentro del escritorio, simplemente:

```bash
selftest
```

Revisa la plataforma, el rendimiento, el usuario, la carpeta compartida, los stacks de
Kobuki y COLA2, el escritorio del navegador y los finales de línea. Termina con un resumen:

```
=== RESUMEN ===
  Correctos: 40   Avisos: 1   Fallos: 0

  Entorno correcto. Puedes empezar a trabajar.
```

Si hay fallos, los lista con la sección donde salió, la causa y qué hacer. Ejecútalo
**siempre** antes de pedir ayuda, y pega su salida entera si tienes que preguntar: la
cabecera incluye la versión de la imagen, que es lo primero que necesita saber el profesor.

### Prueba a fondo, con el robot en marcha

Lo anterior comprueba que todo *está*. Si quieres comprobar que todo *funciona*, hay una
prueba que arranca de verdad el simulador del Kobuki (tarda un minuto):

```bash
docker compose exec ros-dev selftest --completo
```

Añade una sección 8 que levanta `roscore` y Gazebo con el modelo del Kobuki, y verifica que
circulan `/odom`, `/joint_states` y `/mobile_base/commands/velocity`. Al terminar lo cierra
todo.

> Si ya tienes ROS en marcha, esta sección **se salta** en vez de matarte la simulación.
> Ciérrala y repite si la quieres.

## Atajos de la terminal del escritorio

| Alias | Qué hace |
|---|---|
| `cw` | ir al workspace |
| `cm` | compilar el workspace (Release) |
| `sw` | recargar `devel/setup.bash` |
| `wsclean` | borrar `build/` y `devel/` |
| `selftest` | autotest del entorno |
| `cpl0` / `cpl1` / `cpl2` | ir a `code/PL0`, `code/PL1` o `code/PL2` |
| `kobuki_sim` | **PL1**: modelo del Kobuki en Gazebo |
| `kobuki_keyop` | **PL1**: teleoperación por teclado |
| `sparus2` | **PL2**: SparusII en la piscina |
| `girona500` | **PL2**: Girona500 en la piscina |
| `girona500_valve` | **PL2**: Girona500, giro de válvula |
| `girona500_wind` | **PL2**: Girona500, aerogenerador |

> El alias de limpieza se llama `wsclean` y **no** `rosclean`: `rosclean` ya es una
> herramienta de ROS y taparla con un alias que hace `rm -rf` es una trampa.

## PL0 — Introducció a ROS

No necesita ningún alias del curso: es `turtlesim` y las herramientas estándar de ROS. Tu
paquete (`pl0_cognom`) va dentro de `code/PL0/`. Sigue el enunciado de la práctica.

## PL1 — Odometria en robots amb rodes (Kobuki)

Si no tienes un Kobuki físico conectado, levanta su modelo simulado:

```bash
kobuki_sim
```

Abre Gazebo con el Kobuki en un mundo vacío. Las dos vías (robot físico o simulado) exponen
la **misma interfaz ROS**:

| Topic / interfaz | Tipo | Sentido |
|---|---|---|
| `/odom` | `nav_msgs/Odometry` | el driver **publica** |
| `/mobile_base/commands/velocity` | `geometry_msgs/Twist` | el alumno **publica** |
| `/mobile_base/sensors/imu_data` | `sensor_msgs/Imu` | el driver **publica** |
| `/joint_states` | `sensor_msgs/JointState` | el driver **publica** |
| `/mobile_base/commands/reset_odometry` | `std_msgs/Empty` | el alumno **publica** |
| `/mobile_base/events/bumper` | `kobuki_msgs/BumperEvent` | el driver **publica** |

Tu paquete (`pl1_cognom`) va dentro de `code/PL1/`. `kobuki_node` no expone un ejecutable
propio: se carga como *nodelet* (ver `roslaunch kobuki_node minimal.launch` para el robot
físico). Sigue el enunciado de la práctica para el detalle del modelo cinemático y del
experimento de caracterización de deriva.

## PL2 — Navegació per estima submarina (COLA2 + Stonefish)

Aquí **una sola terminal** basta: el launch levanta el simulador y toda la pila COLA2.

```bash
sparus2          # o girona500, girona500_valve, girona500_wind
```

Tarda **~60 segundos** en levantar los 33 nodos. Paciencia antes de dar nada por roto.

Cuando esté listo verás ~74 topics bajo `/sparus2/...` (o `/girona500/...`): navegación,
control, seguridad, thrusters y sensores. Tu paquete (`pl2_cognom`) va dentro de
`code/PL2/`. La práctica trabaja principalmente sobre un rosbag de datos reales o simulados
que te facilitará el profesorado; el simulador sirve para explorar la interfaz de topics de
COLA2 antes de programar el integrador de dead reckoning.

### Sobre los gráficos: irá lento, y es normal

El escritorio **no tiene GPU**. Mesa entrega OpenGL 4.5 por `llvmpipe`, que es un
rasterizador **por software**. Stonefish arranca y simula bien, pero **el dibujado es
lento**. La física va a velocidad nominal, así que para practicar control y navegación
sirve perfectamente.

Por eso la calidad gráfica va en `low` por defecto. Con `high` los shaders no llegan ni a
compilar y no se dibuja nada. Si tienes una GPU de verdad y quieres probar:

```bash
roslaunch cola2_stonefish sparus2_tank_simulation.launch graphics_quality:=high
```

## Si algo falla

Lanza primero `selftest`. Y si no, busca aquí el síntoma:

| Síntoma | Causa y solución |
|---|---|
| `port is already allocated` | Ya tienes un contenedor arriba. `docker ps` para ver cuál; usa ése. |
| No veo mis ficheros dentro del contenedor | Arrancaste con `docker run` en vez de `docker compose up -d`. Y recuerda: van a `src/student/`, no a `src/`. |
| `pull access denied` o `repository does not exist` | Revisa que el `image:` diga exactamente `amt132/ampliacio_robotica:2026`. Si está bien escrito, avisa al profesor: la imagen es pública y no debería pedirte nada. |
| `docker compose` dice *is not a docker command* | Tienes Compose v1 (`docker-compose`, con guion). Actualiza Docker Desktop. |
| `no configuration file provided` | No estás en la carpeta donde está `docker-compose.yml`. `cd` hasta ella. |
| La descarga se corta a medias | Vuelve a lanzar `docker compose up -d`: continúa por las capas que ya tiene, no empieza de cero. |
| `no space left on device` | Menos de 12 GB libres. Libera disco y, si has probado otras imágenes, `docker system prune -a`. |
| `rospack find ...` dice *package not found* pero los atajos existen | Problema de orden de sourcing. Comprueba `echo $ROS_PACKAGE_PATH`: debe empezar por `/home/ubuntu/catkin_ws/src`. |
| "Untrusted application launcher" al pulsar un icono | No debería pasar ya. Si pasa: `docker exec amprobotica-ros cat /var/log/course_desktop_setup.log` |
| VSCodium no abre al hacer doble clic | Necesita `--no-sandbox`, ya viene puesto. Si falla, mira el log de arriba. |
| Stonefish abre ventana pero no dibuja | Calidad gráfica en `high`. Ver la sección de gráficos. |
| El escritorio se cierra solo | Falta memoria compartida: arranca con `docker compose`, no con `docker run`. |
| No puedo escribir en `code/` (Linux) | `sudo chown -R 1000:1000 code` |
| `localhost:6080` no carga nada | Lanza `selftest`: su sección 6 dice si el escritorio está sirviendo **dentro** del contenedor. Si ahí sale todo OK, el problema es de tu navegador o del puerto (¿otro contenedor ocupando el 6080?); si sale FALLO, `docker compose restart`. |
| `roscore` dice *Unable to contact my own server* | El nombre del contenedor no resuelve. Lo detecta el `selftest` (sección 2). |
| `cm` falla con errores raros del compilador | Disco de Docker lleno. El `selftest` avisa; desde tu ordenador: `docker system prune -a`. |
| Todo va lentísimo (Mac con chip Apple) | Es emulación. El `selftest` la detecta en la sección 1. Activa Rosetta en Docker Desktop > Settings > General. |

---

# Guía del profesor

## Construir

```bash
cd ampliacio_robotica
DOCKER_BUILDKIT=1 docker build --progress=plain -f docker/Dockerfile.ros_base -t amprobotica:dev .
```

El comando es el mismo en los tres sistemas y **no lleva `--platform`**: el `FROM` ya fija
`linux/amd64` y el digest de la base. Ver *Compatibilidad*. Nota que el contexto de build
sigue siendo la raíz del repositorio (`.`), no `docker/`: el Dockerfile hace
`COPY docker/...` porque los ficheros que copia viven en esa subcarpeta.

Los pasos marcados `[FRÁGIL]` (capas 4, 5, 6 y 7-bis) están aislados a propósito para que,
si el build falla, el error salga localizado.

## Probar antes de publicar

```bash
docker compose up -d
docker compose exec ros-dev selftest              # comprobaciones estáticas, exit 0 si todo bien
docker compose exec ros-dev selftest --completo   # + arranca el Kobuki simulado de verdad (~1 min)
```

El autotest está escrito para dar el mismo resultado lo lance root (`docker compose exec`)
o el alumno desde el escritorio: todo lo que depende de permisos, de `$HOME` o del entorno
interactivo lo ejecuta **como `ubuntu`**. Si añades comprobaciones de ese tipo, hazlo
también — comprobarlas como root da falsos `[ OK ]`, porque root escribe donde quiere.

Conviene construir con la versión marcada, para que la cabecera del autotest identifique la
imagen cuando un alumno pegue su salida:

```bash
docker build -f docker/Dockerfile.ros_base \
  --build-arg IMAGE_VERSION="2026 rev1 $(git rev-parse --short HEAD)" -t amprobotica:dev .
```

Para probar en local antes de publicar en Docker Hub, crea un `docker-compose.override.yml`
(está en `.gitignore`, no llega a los alumnos):

```yaml
services:
  ros-dev:
    image: amprobotica:dev
    pull_policy: never
```

Después, comprobación manual de los stacks:

```bash
# Kobuki (PL1), en el escritorio
kobuki_sim
rostopic list                                  # /odom /joint_states /mobile_base/...
rostopic pub -r5 /mobile_base/commands/velocity geometry_msgs/Twist '{linear: {x: 0.15}}'
rostopic hz /odom

# Submarino (PL2)
sparus2
rostopic hz /sparus2/navigator/odometry       # ~10 Hz
```

> **Si pruebas por `docker exec` en vez de dentro del escritorio**, espera a que el
> servidor X esté arriba o `rviz` y `stonefish_simulator` morirán con
> `qt.qpa.xcb: could not connect to display :1`. No es un fallo de la imagen:
> ```bash
> until docker exec -u ubuntu -e DISPLAY=:1 <cont> xdpyinfo >/dev/null 2>&1; do sleep 2; done
> ```

## Publicar en Docker Hub

El repositorio es **`amt132/ampliacio_robotica`**, y ya está puesto en la línea `image:`
del `docker-compose.yml`, así que los alumnos no tienen que tocar nada.

```bash
docker login -u amt132                                     # pide un Access Token, no la contraseña
docker tag amprobotica:dev amt132/ampliacio_robotica:2026
docker push amt132/ampliacio_robotica:2026
```

Tres cosas que hay que hacer bien o los alumnos no podrán bajarla:

1. **El repositorio debe ser público** (Docker Hub > el repo > *Settings* > *Make public*).
   Si es privado, el alumno recibe `pull access denied` — el mismo mensaje que si el
   nombre estuviera mal, así que es fácil perder una tarde con esto.
2. **Autentícate con un Access Token**, no con la contraseña de la cuenta: Docker Hub >
   *Account Settings* > *Personal access tokens*. Basta con permiso *Read & Write*.
3. **Empuja también el tag `latest`** si quieres que `docker pull amt132/ampliacio_robotica`
   a secas funcione. El compose pide `:2026` explícitamente, así que no es imprescindible.

Comprueba que ha quedado pública **sin cerrar tu sesión** (un `docker logout` te obligaría
a volver a hacer login). Basta con pedir un token anónimo, que es exactamente lo que hace
el Docker de un alumno:

```bash
TOK=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:amt132/ampliacio_robotica:pull" | grep -o '"token":"[^"]*' | cut -c10-)
curl -sI -H "Authorization: Bearer $TOK" \
     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
     https://registry-1.docker.io/v2/amt132/ampliacio_robotica/manifests/2026 | head -1
```

`HTTP/2 200` significa que cualquiera puede bajarla. Un `401` es que el repositorio sigue
privado.

Para comprobar que lo publicado es **exactamente** el build que has verificado, sin
descargar los gigabytes otra vez, compara el *config digest* del manifest remoto con el ID
de tu imagen local: si coinciden, son la misma imagen bit a bit.

```bash
curl -s -H "Authorization: Bearer $TOK" \
     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
     https://registry-1.docker.io/v2/amt132/ampliacio_robotica/manifests/2026 \
  | grep -A3 '"config"' | grep -o 'sha256:[a-f0-9]*'
docker inspect --format '{{.Id}}' amprobotica:dev
```

## Republicar una versión corregida

Esto hay que hacerlo bien, porque el fallo es silencioso: **Docker nunca vuelve a
descargar un tag que ya tiene en caché**. Si corriges la imagen y la publicas con el mismo
tag, el alumno que ya la bajó se queda con la vieja para siempre, y el síntoma en clase es
el peor posible: *"a unos les funciona y a otros no"*, con el mismo `docker-compose.yml`.

### Primero: ¿la tiene ya alguien?

La pregunta real es **si ya has repartido el `docker-compose.yml`**:

- **Todavía no lo ha visto ningún alumno** → puedes **sobrescribir el mismo tag** sin
  consecuencias.
- **Ya lo tienen** → **tag nuevo obligatorio** (`2026b`, `2026-rev2`…). No hay atajo, y no
  sirve borrar y volver a subir: lo que manda es la caché del ordenador del alumno.

El contador de Docker Hub ayuda, pero **no lo tomes como prueba**: cuenta también tus
propias descargas y las de tus verificaciones.

```bash
curl -s https://hub.docker.com/v2/repositories/amt132/ampliacio_robotica/ | grep -o '"pull_count":[0-9]*'
```

### Procedimiento

1. Haz el cambio. Si es estructural, **añade su comprobación al `selftest`** en el mismo
   paso: es lo que evita publicar una imagen rota.
2. Reconstruye **cambiando la versión**, que es lo que luego identifica la imagen:
   ```bash
   docker build -f docker/Dockerfile.ros_base --build-arg IMAGE_VERSION="2026 rev2" -t amprobotica:dev .
   ```
3. Verifica antes de subir nada:
   ```bash
   docker compose up -d --force-recreate
   docker compose exec ros-dev selftest
   docker compose exec ros-dev selftest --completo
   ```
4. Verifica **la ruta del alumno**, apartando el override (si no, estás probando tu imagen
   local, no la publicada): ver el aviso dentro de `docker-compose.override.yml`.
5. Sube:
   ```bash
   docker tag amprobotica:dev amt132/ampliacio_robotica:2026b
   docker push amt132/ampliacio_robotica:2026b
   ```
6. **Cambia el tag en los dos sitios**: la línea `image:` del `docker-compose.yml` y la
   copia del compose que lleva `INSTALLACIO.md`. Si solo cambias uno, la mitad de los
   alumnos seguirá instalando la versión vieja.
7. Comprueba el digest publicado con los comandos de la sección anterior.
8. Avisa a los alumnos: **no se enteran solos**.

### Qué tienen que hacer ellos

```bash
docker compose down
# sustituir el docker-compose.yml (o editar a mano la línea 'image:')
docker compose up -d
```

Tres cosas que conviene decirles al avisar:

- **No pierden su código.** `code/` está en su disco, no en la imagen.
- **La descarga suele ser pequeña**, no toda la imagen otra vez: solo bajan las capas que
  han cambiado. De ahí una consecuencia práctica: **mete los cambios lo más al final
  posible del Dockerfile**; una corrección en una capa temprana invalida todas las
  siguientes y convierte una actualización de megabytes en uno de varios gigas.
- **La imagen vieja se les queda ocupando disco.** Para recuperarlo:
  `docker image rm amt132/ampliacio_robotica:<tag-viejo>`

### Qué no hacer

- **No borres el tag antiguo de Docker Hub** mientras alguien pueda estar usándolo. Si un
  alumno hace `docker compose down` y ya no está el tag que pide su fichero, se queda sin
  entorno a mitad de práctica. Cuesta cero dejarlo publicado.
- **No republiques sin cambiar `IMAGE_VERSION`**: la cabecera del `selftest` es lo único
  que te dice qué versión corre cada alumno cuando te pegue su salida, y mentiría.
- **No te fíes de `latest`.** El compose pide un tag explícito a propósito; `latest` es
  justo el tag que más se cachea y menos se controla.

### Versiones publicadas

| Tag | Fecha | Digest del manifest | Qué lleva |
|---|---|---|---|
| `2025` | 2026-07-31 | `ca5e430375…` | Primera versión del curso: stack Pioneer 3DX + COLA2. **Retirada**: ningún enunciado vigente (PL0/PL1/PL2) usa el stack Pioneer; ver `2026`. |
| `2026` | *(pendiente de publicar)* | — | Reestructuración por prácticas (PL0/PL1/PL2): retira Pioneer/MobileSim/RosAria, añade el stack Kobuki para PL1, renombra `codigo/`→`code/` y `src/alumno`→`src/student`. |

> **La imagen pesa varios GB** (la base noVNC ya son ~7.7 GB; los stacks de Kobuki y COLA2
> añaden varios GB más). Avisa a los alumnos de que la descarguen en casa. Si el aula tiene
> servidor local, una copia ahí ahorra el disgusto.

## Compatibilidad: Windows, macOS y Linux

Tres decisiones sostienen que la misma imagen y el mismo compose funcionen en los tres
sistemas sin que el alumno edite nada:

**1. La arquitectura está fijada en el `FROM`.** La base `tiryoh/ros-desktop-vnc` es
**multi-arch** (amd64 *y* arm64). En un Mac con chip Apple, un build sin `--platform`
bajaría la base arm64 y algunas de las compilaciones C++ desde fuente (Stonefish, cola2_lib,
Kobuki) asumirían la arquitectura equivocada. Por eso el Dockerfile lleva
`FROM --platform=linux/amd64`.

**2. El digest de la base está fijado.** El tag `:noetic` es mutable; el digest no. Para
actualizarlo a conciencia:
```bash
docker buildx imagetools inspect docker.io/tiryoh/ros-desktop-vnc:noetic \
  --format '{{.Manifest.Digest}}'
```

**3. Los finales de línea están forzados a LF** por el `.gitattributes`. Git for Windows
trae `core.autocrlf=true`: sin esto, un clon en Windows entrega los scripts del curso con
shebang `#!/usr/bin/env bash\r` y el contenedor responde *"bad interpreter: No such file or
directory"* — un error que no menciona ni Windows ni CRLF. El Dockerfile además pasa un
`sed 's/\r$//'` sobre esos scripts como red de seguridad.

**Construir desde un host arm64** necesita emulación QEMU (Docker Desktop la trae; en Linux
arm64: `docker run --privileged --rm tonistiigi/binfmt --install amd64`). Aun así,
**construye en un host amd64 si puedes**: emular las compilaciones C++ desde fuente es lento.

## El usuario del escritorio: `ubuntu`, y no viene de serie

Contraintuitivo, así que conviene leerlo antes de tocar el Dockerfile. El
`/entrypoint.sh` de la base hace:

```bash
USER=${USER:-root}
HOME=/root
if [ "$USER" != "root" ]; then useradd --create-home ... "$USER"; HOME="/home/$USER"; fi
```

Es decir: **por defecto el escritorio corre como root**, y el usuario `ubuntu` **no existe
en la imagen** — lo crea el entrypoint *al arrancar*, y solo si `USER` está definida.

Que corra como `ubuntu` (uid 1000) es una decisión nuestra, y requiere **las tres cosas**:
crear el usuario en build time (si no, el `chown` falla con *invalid user*), cederle el
workspace con ese `chown`, y exportar `ENV USER=ubuntu` al final.

El motivo es **Linux**: el bind mount de `code/` conserva el uid del host, así que con el
escritorio como root los ficheros que crea el alumno le salen `root:root` en su propio
disco. Con uid 1000 coinciden.

**No añadas la directiva `USER` de Docker:** el entrypoint necesita empezar como root para
montar la sesión y luego baja a `ubuntu` con `gosu`.

## Parches al upstream, y por qué

El build modifica ficheros de `cola2_stonefish`. Ambos parches llevan **guarda**: si el
upstream cambia, el build falla en vez de publicar una imagen rota en silencio.

**1. `graphics_quality: high` → `<arg default="low">`.** Sin GPU, `high` produce
`[ERROR] Failed to compile shader` en cadena y no se dibuja nada; `low` llega a
`Ready for running` con Bullet Physics. Los 4 launch traen `high` fijo (`value=`, que un
`<include>` no deja sobreescribir desde fuera).

**2. `teleoperation_node.py` → `teleoperation_node`.** `cola2_core@noetic-24.01` migró ese
nodo de Python a C++, pero los launch de `cola2_stonefish` siguen pidiendo el `.py`. Sin el
parche, roslaunch aborta ese nodo y detrás cae `keyboard_to_teleoperation`, que espera su
servicio `enable_thrusters`: **te quedas sin teleoperación por teclado**. Comprobado en las
4 ramas de `cola2_stonefish` (`v1.3`, `noetic-24.01`, `master`, `noetic-24.01-MRS`):
ninguna está alineada con este core, así que no se arregla eligiendo otro tag.

### Limitación conocida (COLA2)

`cola2_stonefish` declara `<exec_depend>eca_5emicro_manipulator_description</exec_depend>`
y **ese repo no es público** en `github.com/srv`. Al ser `exec_depend` y no `build_depend`,
`catkin_make` no falla; lo único inservible es el escenario `girona500_eca5emicro.scn`
(brazo manipulador).

### Por qué Kobuki se compila desde fuente

Noetic solo publica media pila de Kobuki: `packages.ros.org` trae `kobuki-core`,
`kobuki-driver`, `kobuki-msgs`, `kobuki-dock-drive` y `kobuki-ftdi`, pero **no**
`kobuki_node`, `kobuki_keyop`, `kobuki_description`, `kobuki_gazebo` ni los `yocs_*` de los
que depende `kobuki_node` — esa parte se quedó en Melodic. Comprobado sobre el índice de
paquetes:
```bash
curl -sL http://packages.ros.org/ros/ubuntu/dists/focal/main/binary-amd64/Packages.gz \
  | gunzip | grep '^Package: ros-noetic-kobuki'
```
De ahí que se clonen los repos de `yujinrobot` (capa 7-bis del Dockerfile). Las ramas no
coinciden entre repos y no es un descuido: `kobuki_msgs` y `kobuki_core` sí tienen rama
`noetic`; el resto se queda en `melodic` (`kobuki`, `kobuki_desktop`) o en `devel`
(`yujin_ocs`). Compilan igual contra Noetic y Gazebo 11.

### Por qué todo se hornea en la imagen

El `docker-entrypoint.sh` de referencia clonaba los 11 repos de COLA2 y ejecutaba
`catkin build` **en cada arranque**, sobre un bind mount. Aquí no: esto publica una imagen
de aula, y eso serían ~15 minutos y conexión a internet por alumno **y por sesión**.

## El escritorio: dos arreglos a la imagen base

**"Untrusted application launcher".** Caja marca un `.desktop` como de confianza si empieza
por el shebang `#!/usr/bin/env xdg-open` (ya está) **y tiene bit de ejecución**. Lo segundo
falla por un bug del entrypoint:

```bash
chmod +x "$HOME/Desktop/*.desktop"     # <-- glob ENTRE COMILLAS, nunca se aplica
```

**VSCodium no abre.** El sandbox de Chromium necesita user namespaces sin privilegios y el
contenedor no puede: aborta con `FATAL ... zygote_host_impl_linux.cc` antes de crear
ventana. Necesita `--no-sandbox`.

| Qué | Dónde se arregla | Por qué ahí |
|---|---|---|
| `/usr/share/applications/codium.desktop` | Dockerfile, capa 11 | Vive en la imagen; el entrypoint no lo toca |
| `~/Desktop/*.desktop` | [docker/course_desktop_setup.sh](docker/course_desktop_setup.sh) | El entrypoint **recrea `~/Desktop` en cada arranque** |

El script lo lanza supervisord vía `/etc/supervisor/conf.d/zz-course-desktop.conf`. El
nombre propio importa: el entrypoint reescribe `conf.d/supervisord.conf`, pero **solo ese
fichero**, y el `supervisord.conf` principal incluye `conf.d/*.conf` entero.

## Seguridad

El escritorio noVNC **no pide contraseña**, y el usuario `ubuntu` tiene `sudo`: quien
llegue al puerto tiene el contenedor entero. Por eso el `docker-compose.yml` publica el
puerto como `127.0.0.1:6080:80` y no como `6080:80` (que en Docker significa `0.0.0.0` y
dejaría el escritorio abierto a toda la red del aula). Para acceso remoto, un túnel SSH.

## Troubleshooting del build

**Capa 4 — `cola2_lib` no compila.** Compilación C++ desde fuente. Si falla el `cmake`,
revisa las dependencias de sistema de la capa 3.

**Capa 5 — Stonefish no compila.** Es la capa más larga de la imagen. Casi siempre falta
una librería de la capa 3 (`libglm-dev`, `libsdl2-dev`, `libfreetype6-dev`,
`libgl1-mesa-dev`).

**Capa 6 — `Could not find ... pcl_ros`.** La base noVNC es `ros-desktop`, no
`desktop-full`: hay dependencias ROS que hay que pedir explícitamente (capa 5-bis). Para
regenerar la lista si añades repos:
```bash
find src -name package.xml -exec grep -hoE '<(depend|.*_depend)>[^<]+' {} \; \
  | sed -E 's/.*>//' | sort -u
```

**Capa 7-bis — Kobuki falla con `Error 127`.** Falta ignorar `kobuki_qtestsuite` con
`CATKIN_IGNORE`: le falta el generador de interfaces PyQt y el mensaje de error no lo dice.
Revisa que la lista de `CATKIN_IGNORE` de esa capa siga completa.

**Runtime — `/usr/bin/env: 'python': No such file or directory` (cientos de veces).**
Falta `python-is-python3`. Los nodos Python de COLA2 llevan shebang `#!/usr/bin/env python`
y Ubuntu 20.04 solo trae `python3`. Síntoma engañoso: roslaunch arranca, el núcleo C++
funciona, pero ~20 nodos entran en bucle de respawn.

**Runtime — los atajos existen pero `rospack` no encuentra nada.** Orden de sourcing. Bash
lee `/etc/bash.bashrc` y *después* `~/.bashrc`, y el entrypoint añade a `~/.bashrc` un
`source /opt/ros/noetic/setup.bash` que **reescribe `ROS_PACKAGE_PATH` desde cero**. La
capa 10 lo resuelve pre-sembrando `~/.bashrc` para que el entorno del curso quede el
último.
