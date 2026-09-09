# CLAUDE.md — Contexto del repositorio `ampliacio_robotica`

## Qué es esto

**No es una aplicación: es la receta de una imagen Docker de aula.** Asignatura
*Ampliació de Robòtica* (UIB). El profesor construye la imagen **una vez**, la publica en
Docker Hub, y los alumnos solo hacen `git clone` (ver [INSTALLACIO.md](INSTALLACIO.md)),
`docker compose up -d` y abren un escritorio ROS Noetic en el navegador (noVNC).

La imagen lleva **tres stacks**, uno por práctica de laboratorio (PL0/PL1/PL2 — los
enunciados viven fuera de este repo, en documentos .docx del profesor):

- **PL0 — Introducció a ROS**: `turtlesim` y herramientas estándar, ya en la base. No añade
  nada a la imagen.
- **PL1 — Odometria en robots amb rodes**: Kobuki (Yujin Robot). Driver (`kobuki_node`,
  nodelet) + modelo simulado en Gazebo (`kobuki_desktop`). Se compila desde fuente porque
  Noetic solo publica media pila del Kobuki (ver invariante 3-bis).
- **PL2 — Navegació per estima submarina**: AUV 3D con `cola2_lib` + Stonefish + COLA2 ROS
  + SparusII/Girona500. Arranca en una sola terminal (`sparus2`, `girona500`, …), ~60 s
  hasta levantar 33 nodos.

El entregable real es la imagen. Ningún stack trae ya un paquete de curso horneado: los
tres enunciados piden que el alumno cree su propio paquete catkin (`catkin_create_pkg`)
dentro de `code/PL0/`, `code/PL1/` o `code/PL2/` según la práctica.

Idioma del proyecto: **castellano/catalán**. Comentarios y mensajes de commit van en
castellano; el documento de instalación para el alumno ([INSTALLACIO.md](INSTALLACIO.md))
va en catalán porque así se pidió — mantenlo así al editar.

## Mapa de ficheros

| Fichero | Rol | Público |
|---|---|---|
| [docker-compose.yml](docker-compose.yml) | Arranque del contenedor | ALUMNO |
| [README.md](README.md) | Guía completa: construir, probar, publicar, troubleshooting | ambos |
| [INSTALLACIO.md](INSTALLACIO.md) | Instalación paso a paso (català), desde cero | ALUMNO |
| `code/PL0/`, `code/PL1/`, `code/PL2/` | Vacías en el repo (solo `.gitkeep`); volumen del alumno, una subcarpeta por práctica | ALUMNO |
| [docker/Dockerfile.ros_base](docker/Dockerfile.ros_base) | Construcción de la imagen, 12 capas numeradas | PROFESOR |
| [docker/course_aliases.sh](docker/course_aliases.sh) | Atajos; va a `/etc/course_aliases.sh` | — |
| [docker/course_selftest.sh](docker/course_selftest.sh) | Autotest → `/usr/local/bin/selftest` en la imagen | ambos |
| [docker/course_desktop_setup.sh](docker/course_desktop_setup.sh) | Arreglos del escritorio, en cada arranque | — |
| [docker/requirements_py38.txt](docker/requirements_py38.txt) | Deps Python con versión fijada | — |
| [.gitattributes](.gitattributes) | Fuerza LF; sin esto Windows rompe los `.sh` | — |

El Dockerfile hace `COPY docker/...`: el **contexto de build sigue siendo la raíz del
repo** (se invoca con `-f docker/Dockerfile.ros_base .`, no `-f docker/Dockerfile.ros_base
docker/`). Si mueves algo dentro de `docker/`, actualiza el `COPY` correspondiente.

## Las invariantes que NO se pueden romper

### 1. El usuario del escritorio: `ubuntu` (uid 1000), y no viene de serie

La decisión de diseño más importante del repo, y la más fácil de romper porque el
comportamiento de la imagen base es **al revés de lo que parece**. Su `/entrypoint.sh` hace:

```bash
USER=${USER:-root}
HOME=/root
if [ "$USER" != "root" ]; then
    useradd --create-home --groups adm,sudo "$USER"   # se crea EN RUNTIME
    HOME="/home/$USER"
fi
... exec supervisord   # el VNC arranca con: gosu "$USER" ...
```

Dos consecuencias que hay que tener presentes siempre:

1. **El usuario `ubuntu` no existe en la imagen.** Lo crea el entrypoint al arrancar. En
   build time no está, así que cualquier `chown ubuntu` en un `RUN` falla con *invalid
   user* si no lo creamos antes nosotros.
2. **Por defecto el escritorio corre como root**, con `HOME=/root`. Que corra como
   `ubuntu` es una decisión *nuestra*, no el comportamiento de la base.

Por eso hacen falta **las tres cosas juntas** en
[docker/Dockerfile.ros_base](docker/Dockerfile.ros_base): `useradd` con uid 1000 al
principio, el `chown -R` de la capa 8, y `ENV USER=ubuntu` al final. Quita cualquiera de
las tres y el build o el arranque se rompen.

El motivo de elegir no-root es **Linux**: el bind mount de `code/` conserva el uid del
host, así que con el escritorio como root los ficheros que crea el alumno le salen
`root:root` en su propio disco. Con uid 1000 coinciden. En Windows/macOS Docker Desktop
remapea y da igual — pero así los tres sistemas se comportan igual.

`ENV USER` va **al final** a propósito: durante el build seguimos siendo root y catkin/pip
miran `$USER`. En el arranque, el `useradd` del entrypoint fallará con *user already
exists*; es inofensivo, el script no lleva `set -e`.

**No añadas la directiva `USER` de Docker.** El entrypoint necesita empezar como root para
montar la sesión y luego baja a `ubuntu` con `gosu`.

La ruta del workspace aparece en **cuatro sitios que deben coincidir siempre**:
- `ENV CATKIN_WS` / `ENV COURSE_CODE_DIR` en
  [docker/Dockerfile.ros_base](docker/Dockerfile.ros_base) (derivados de `COURSE_USER`)
- el `chown -R` al final de la capa 8 — sin él, `cm` falla para el alumno
- el fallback `: "${CATKIN_WS:=...}"` de [docker/course_aliases.sh](docker/course_aliases.sh)
- el `volumes:` de [docker-compose.yml](docker-compose.yml)

### 1-bis. El orden de sourcing (capa 10) — la trampa más fina

Bash lee `/etc/bash.bashrc` y **después** `~/.bashrc`. El entrypoint añade a `~/.bashrc`
un `source /opt/ros/noetic/setup.bash` que **reescribe `ROS_PACKAGE_PATH` desde cero**. Si
el entorno del curso se monta solo en `/etc/bash.bashrc`, el overlay del workspace se
pierde: los alias siguen ahí (mismo fichero) pero `rospack find` de un paquete del curso da
*package not found*. Síntoma: "los atajos existen pero nada funciona".

La capa 10 lo resuelve poniendo todo en `/etc/course_env.sh` y **pre-sembrando** en cada
`~/.bashrc` las dos líneas que el entrypoint busca con `grep`, para que no añada nada y el
bloque del curso quede el último. Si tocas esa capa, verifica siempre:
```bash
echo $ROS_PACKAGE_PATH   # debe empezar por /home/ubuntu/catkin_ws/src
```

### 2. El contrato de topics de PL1 (Kobuki)

El plugin de Gazebo (`gazebo_ros_kobuki`) y el driver físico (`kobuki_node`) exponen la
**misma interfaz**, con prefijo `mobile_base` por defecto:

| Topic | Tipo | Dirección |
|---|---|---|
| `/odom` | `nav_msgs/Odometry` | el driver publica |
| `/mobile_base/commands/velocity` | `geometry_msgs/Twist` | el alumno publica |
| `/mobile_base/sensors/imu_data` | `sensor_msgs/Imu` | el driver publica |
| `/joint_states` | `sensor_msgs/JointState` | el driver publica |

`kobuki_node` **no genera un ejecutable propio**: se carga como *nodelet*
(`nodelet load kobuki_node/KobukiNodelet ...`, ver `minimal.launch`). No busques un binario
`kobuki_node`; la comprobación correcta es `devel/lib/libkobuki_nodelet.so`.

### 3. Reproducibilidad y multiplataforma

Objetivo: **la misma imagen y el mismo compose en Windows, macOS y Linux**, sin que el
alumno edite nada. Lo sostienen estos anclajes:

- **`FROM --platform=linux/amd64`**. La base `tiryoh/ros-desktop-vnc` es **multi-arch**
  (amd64 *y* arm64). Sin el flag, un build en Mac Apple baja la base arm64 y las
  compilaciones C++ desde fuente (Stonefish, cola2_lib, Kobuki) asumen la arquitectura
  equivocada. **No lo quites.**
- **Digest de la base fijado** (`@sha256:...`): el tag `:noetic` es mutable. Refrescar con
  `docker buildx imagetools inspect ... --format '{{.Manifest.Digest}}'`.
- **`.gitattributes` con `eol=lf`**. Git for Windows trae `core.autocrlf=true`: sin esto,
  los scripts del curso llegan con shebang `#!/usr/bin/env bash\r` → *bad interpreter*. El
  Dockerfile además pasa `sed 's/\r$//'` sobre ellos como red de seguridad.
- **`platform: linux/amd64` en el compose**, sin comentar, para los tres sistemas.

Además:

- Todos los refs de fuente (COLA2/Stonefish y Kobuki) van fijados a **commit**, no a tag,
  para que dos construcciones separadas en el tiempo den la misma imagen. Actualizar con
  `git ls-remote <repo>.git <ref>`.
- Las versiones de [docker/requirements_py38.txt](docker/requirements_py38.txt) están
  fijadas porque son las últimas compatibles con Python 3.8. Todo lo que se añada ahí lleva
  versión.

### 3-bis. Por qué Kobuki se compila desde fuente

Noetic solo publica media pila: `packages.ros.org` trae `kobuki-core`, `kobuki-driver`,
`kobuki-msgs`, `kobuki-dock-drive`, `kobuki-ftdi`, pero **no** `kobuki_node`,
`kobuki_keyop`, `kobuki_description`, `kobuki_gazebo` ni los `yocs_*` de los que depende
`kobuki_node` — se quedaron en Melodic. Comprobado sobre el índice de paquetes (ver README,
sección *Por qué Kobuki se compila desde fuente*).

Los repos de `yujinrobot` no comparten rama: `kobuki_msgs` y `kobuki_core` sí tienen
`noetic`; `kobuki`/`kobuki_desktop` se quedan en `melodic`, `yujin_ocs` en `devel`.
Compilan igual contra Noetic/Gazebo 11 — no es un descuido, está verificado con un build
real.

`yujin_ocs` trae ~15 paquetes; Kobuki solo necesita `yocs_cmd_vel_mux`,
`yocs_controllers` y `yocs_velocity_smoother`. Los demás se excluyen con `CATKIN_IGNORE`
(capa 7-bis), igual que `kobuki_qtestsuite` (falla con *Error 127* si no se ignora: le
falta el generador de interfaces PyQt) y los paquetes de dashboard/tutorial/app-manager que
el curso no usa.

### 4. Las capas `[FRÁGIL]`

Las capas 4 (cola2_lib), 5 (Stonefish), 6 (paquetes ROS de COLA2) y 7-bis (Kobuki) están
**aisladas a propósito** en `RUN` propios para que un fallo salga localizado. No las
fusiones para "optimizar capas". Fallos y salidas conocidas están en el *Troubleshooting*
del README.

### 5. Seguridad de red

El puerto se publica como `127.0.0.1:6080:80`, **nunca** `6080:80` (que en Docker
significa `0.0.0.0`). El escritorio no pide contraseña; exponerlo lo deja abierto a toda la
red del aula. Para acceso remoto, túnel SSH.

### 5-bis. El stack submarino y sus dos parches al upstream

**Sin GPU.** El escritorio da OpenGL 4.5 por `llvmpipe` (software). Stonefish arranca,
pero `graphics_quality=high` produce `Failed to compile shader` en cadena y no dibuja
nada; `low` funciona. Los 4 launch de `cola2_stonefish` traen `high` **fijo** (`value=`,
que un `<include>` no deja sobreescribir desde fuera) y el build los convierte a
`<arg default="low">`. La **física va a velocidad nominal** (odometría a 9.97 Hz sobre 10);
lo lento es el render.

**Desfase de versiones upstream.** `cola2_core@noetic-24.01` migró `teleoperation_node` de
Python a C++, pero los launch de `cola2_stonefish` siguen pidiendo `teleoperation_node.py`.
Sin parche, ese nodo no arranca y detrás cae `keyboard_to_teleoperation` (espera el
servicio `enable_thrusters`) → sin teleoperación por teclado. **Comprobado: ninguna de las
4 ramas de `cola2_stonefish` está alineada**, así que no se arregla cambiando de tag.

Los dos parches llevan **guarda con `grep -q`**: si el upstream se corrige, el build falla
en vez de publicar una imagen rota en silencio. No quites esas guardas.

**No portar el patrón del `docker-entrypoint.sh` de referencia**: aquel clonaba los 11
repos y hacía `catkin build` en cada arranque sobre un bind mount. Aquí todo se hornea en
la imagen — son ~15 min y red por alumno y por sesión.

**Limitación conocida:** `cola2_stonefish` declara `<exec_depend>` de
`eca_5emicro_manipulator_description`, repo **no público**. Al ser `exec_depend`,
`catkin_make` no falla; solo queda inservible el escenario `girona500_eca5emicro.scn`.

**`catkin_make`, no `catkin build`.** El workspace es de `catkin_make` (el alias `cm`) y
los dos sistemas son incompatibles entre sí. COLA2 y Kobuki compilan bien con `catkin_make`
pese a que su documentación use `catkin build`.

### 5-ter. Arreglos del escritorio: qué va en el build y qué en el arranque

Regla general: **todo lo que el `/entrypoint.sh` de la base recrea al arrancar no se puede
parchear en el Dockerfile.** El entrypoint reescribe `~/Desktop` entero, `~/.vnc/*`,
`~/.bashrc` (append) y `conf.d/supervisord.conf` en cada arranque.

| Problema | Causa | Dónde se arregla |
|---|---|---|
| "Untrusted application launcher" | El entrypoint hace `chmod +x "$HOME/Desktop/*.desktop"` con el **glob entre comillas** → nunca se aplica → ficheros en 644. Caja pide shebang `#!/usr/bin/env xdg-open` (ya está) **y** bit de ejecución | [docker/course_desktop_setup.sh](docker/course_desktop_setup.sh), en arranque |
| VSCodium no abre | Sandbox de Chromium necesita user namespaces sin privilegios; el contenedor no puede → `FATAL zygote_host_impl_linux.cc`. Necesita `--no-sandbox` | Menú: Dockerfile capa 11. Iconos: script de arranque |

El mecanismo de arranque es un programa de supervisord en
`/etc/supervisor/conf.d/zz-course-desktop.conf`. Funciona porque el entrypoint solo
reescribe `conf.d/supervisord.conf` y el `supervisord.conf` principal incluye
`conf.d/*.conf`. **No renombres ese fichero a `supervisord.conf`.**

Comprobación: `docker exec <cont> cat /var/log/course_desktop_setup.log`.

### 5-quater. La única carpeta persistente es `src/student`

`./code` (host, con subcarpetas `PL0/`, `PL1/`, `PL2/`) ↔
`/home/ubuntu/catkin_ws/src/student` (contenedor), vía el `volumes:` del compose. Todo lo
demás vive en la imagen y **se pierde al borrar el contenedor**. El script de arranque deja
un enlace `MY_CODE` en el escritorio para que se encuentre.

catkin descubre paquetes en cualquier nivel de `src/`, así que un paquete del alumno dentro
de `src/student/PL1/pl1_cognom/` se compila igual que uno directamente bajo `src/`.

### 6. El alias de limpieza se llama `wsclean`, no `rosclean`

`rosclean` ya es una herramienta de ROS. Taparla con un alias que hace `rm -rf` del
workspace es una trampa para cualquiera que siga un tutorial genérico.

## Comandos habituales

```bash
# Construir (desde la raíz del repo; el contexto es la raíz, no docker/)
DOCKER_BUILDKIT=1 docker build --progress=plain -f docker/Dockerfile.ros_base -t amprobotica:dev .

# Probar
docker compose up -d
# -> http://localhost:6080

# Publicar (Docker Hub; el repo debe ser PUBLICO o el alumno recibe 'pull access denied')
docker login -u amt132
docker tag amprobotica:dev amt132/ampliacio_robotica:2026
docker push amt132/ampliacio_robotica:2026
```

Apple Silicon: la imagen es x86_64. Construir/publicar con `--platform linux/amd64`; los
alumnos de Mac activan Rosetta en Docker Desktop (el compose ya lleva `platform:
linux/amd64` sin comentar).

### Aliases dentro del escritorio

`cw` (ir al ws) · `cm` (compilar Release) · `sw` (re-sourcear) · `wsclean` (borrar
build/devel) · `cpl0`/`cpl1`/`cpl2` (ir a `code/PLx`) · `kobuki_sim` (Gazebo con el Kobuki)
· `kobuki_keyop` (teleoperación) · `sparus2`/`girona500`/... (COLA2)

## Cómo se verifica un cambio

**Empieza siempre por el autotest** —
[docker/course_selftest.sh](docker/course_selftest.sh), que va a la imagen como
`/usr/local/bin/selftest`. Comprobaciones estáticas, exit 0/1:

```bash
docker compose exec ros-dev selftest              # desde el host, igual en Win/Mac/Linux
selftest                                          # desde una terminal del escritorio
docker compose exec ros-dev selftest --completo   # + sección 8: arranca el Kobuki simulado (~1 min)
```

Corre **dentro** del contenedor a propósito: así el comando es idéntico en los tres
sistemas y no hace falta bash en el host (Windows no lo tiene). Cubre plataforma,
emulación, `/dev/shm`, disco, usuario/entorno interactivo, carpeta compartida (montada,
escribible **por `ubuntu`** y no `ro`, con las tres subcarpetas PL0/PL1/PL2), los stacks
Kobuki y COLA2, servicios VNC/noVNC + puerto 80, display/OpenGL, lanzadores,
`--no-sandbox`, `MY_CODE` y CRLF. El modo `--completo` levanta roscore + Gazebo con el
Kobuki y verifica `/odom`, `/joint_states` y `/mobile_base/commands/velocity`; se **salta**
solo si ya hay un roscore, para no matar la sesión del alumno.

**La regla de oro al añadirle comprobaciones:** `docker compose exec` entra como **root**,
pero el alumno usa el escritorio como `ubuntu`. Cualquier comprobación de permisos, de
`$HOME` o de entorno interactivo hecha como root **miente** — root escribe donde quiere,
su `~/.bashrc` es otro, `supervisorctl` solo le funciona a él, y `xdpyinfo` le falla
siempre (la cookie de X es de `ubuntu`). Para eso está el helper `como_alumno()`: úsalo.

Si tocas algo estructural, **añade su comprobación al selftest**: es la red que evita
publicar una imagen rota.

Después, verificación manual de los pasos de *"Probar antes de publicar"* del README. Los
que cazan fallos de permisos/usuario:

```bash
whoami                        # 'ubuntu', NO root
id                            # uid=1000(ubuntu) gid=1000(ubuntu) groups=...,sudo
echo $CATKIN_WS               # /home/ubuntu/catkin_ws
echo $ROS_PACKAGE_PATH        # DEBE empezar por /home/ubuntu/catkin_ws/src
```

Para probar sin abrir el navegador, el escritorio ya tiene un X en `:1`, así que todo se
puede pilotar desde el host:
```bash
docker exec -u ubuntu <cont> bash -ic 'export DISPLAY=:1; roscore &'
docker exec -u ubuntu <cont> bash -ic 'export DISPLAY=:1; kobuki_sim'
docker exec -u ubuntu <cont> bash -ic 'rostopic list'
```

> **Trampa al verificar por `docker exec`:** lanzar un launch con GUI antes de que
> `Xtigervnc :1` esté arriba da `qt.qpa.xcb: could not connect to display :1` y mata
> `rviz`/`stonefish_simulator`/Gazebo. **No es un fallo de la imagen**, es una carrera del
> método de prueba. Espera al display primero:
> ```bash
> until docker exec -u ubuntu -e DISPLAY=:1 <cont> xdpyinfo >/dev/null 2>&1; do sleep 2; done
> ```

## Al trabajar aquí

- El README es documentación de producto, no notas sueltas: si cambias comportamiento,
  actualiza el README **en el mismo cambio**. Lo mismo para
  [INSTALLACIO.md](INSTALLACIO.md) si el cambio afecta a la instalación.
- Los comentarios largos del Dockerfile explican *por qué*, no *qué*. Son deliberados;
  no los podes al refactorizar.
- `code/PL0/`, `code/PL1/` y `code/PL2/` están en `.gitignore` salvo su `.gitkeep`: son el
  volumen del alumno, no se versiona su contenido.
- Este repositorio **no sigue todavía** la convención de metadata con
  `.claude/essential/` (no existe esa carpeta). El estado de la migración a PL0/PL1/PL2 y
  las tareas pendientes (build de producción, checksums, dataset de PL2, pruebas en
  Windows/macOS reales) no están documentadas en ningún fichero del repo todavía —
  pregúntalo directamente si retomas este trabajo en otra sesión.
