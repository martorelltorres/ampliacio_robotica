#!/bin/bash
# =============================================================================
#  AUTOTEST DEL ENTORNO — Ampliació de Robòtica
# =============================================================================
#  Comprueba que todo está en su sitio ANTES de perder una tarde depurando.
#
#  Se ejecuta DENTRO del contenedor a propósito: así el comando que teclea el
#  alumno es idéntico en Windows, macOS y Linux, y no hace falta que tenga bash
#  en su ordenador (en Windows no lo tiene).
#
#      Desde el ordenador:     docker compose exec ros-dev selftest
#      Desde el escritorio:    selftest
#      Prueba a fondo (~60 s): docker compose exec ros-dev selftest --completo
#
#  REGLA DE ORO DE ESTE FICHERO: el alumno usa el escritorio como 'ubuntu',
#  pero 'docker compose exec' entra como ROOT. Cualquier comprobación de
#  permisos, de HOME o de entorno interactivo hecha como root MIENTE (root
#  escribe donde quiere y su ~/.bashrc no es el del alumno). Por eso todo lo
#  que depende del usuario pasa por como_alumno(), que baja a 'ubuntu' cuando
#  hace falta. Si añades una comprobación de permisos, úsala.
#
#  Código de salida: 0 si no hay fallos, 1 si hay alguno.
# =============================================================================

OK=0; FAIL=0; WARN=0
FALLOS=()
SEC="0"

c_ok()   { printf '  \033[32m[ OK ]\033[0m %s\n' "$1"; OK=$((OK+1)); }
c_bad()  { printf '  \033[31m[FALLO]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); FALLOS+=("[$SEC] $1${2:+ -> $2}"); }
c_warn() { printf '  \033[33m[AVISO]\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
titulo() { SEC="${1%%.*}"; printf '\n\033[1m%s\033[0m\n' "$1"; }

# Se sourcea el entorno del curso porque 'docker compose exec' no lee
# /etc/bash.bashrc. OJO: esto hace que el resto del script tenga CATKIN_WS aunque
# el entorno del alumno esté roto; por eso el entorno interactivo REAL se
# comprueba aparte, en la sección 2, lanzando un bash -i como 'ubuntu'.
[ -f /etc/course_env.sh ] && . /etc/course_env.sh 2>/dev/null
CATKIN_WS="${CATKIN_WS:-/home/ubuntu/catkin_ws}"

ALUMNO_USER="ubuntu"
ALUMNO_HOME="/home/${ALUMNO_USER}"

# Ejecuta algo tal y como lo ejecutaría el alumno. Si el test lo lanza root
# (caso 'docker compose exec'), baja a 'ubuntu'; si ya somos 'ubuntu', se
# ejecuta directamente.
como_alumno() {
    if [ "$(id -u)" -eq 0 ]; then
        runuser -u "$ALUMNO_USER" -- "$@" 2>/dev/null
    else
        "$@" 2>/dev/null
    fi
}
# Igual, pero para una línea de shell (necesita comillas propias).
como_alumno_sh() {
    if [ "$(id -u)" -eq 0 ]; then
        runuser -u "$ALUMNO_USER" -- bash -c "$1" 2>/dev/null
    else
        bash -c "$1" 2>/dev/null
    fi
}

MODO_COMPLETO=0
[ "${1:-}" = "--completo" ] || [ "${1:-}" = "--full" ] && MODO_COMPLETO=1

printf '\n\033[1m=== AUTOTEST DEL ENTORNO DEL CURSO ===\033[0m\n'
printf 'Fecha: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
if [ -f /etc/course_image_version ]; then
    printf 'Imagen: %s\n' "$(tr '\n' ' ' < /etc/course_image_version)"
else
    printf 'Imagen: (sin marca de versión)\n'
fi

# -----------------------------------------------------------------------------
titulo "1. Plataforma y rendimiento"
# -----------------------------------------------------------------------------
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then
    c_ok "Arquitectura: x86_64"
else
    c_bad "Arquitectura inesperada: $ARCH (se esperaba x86_64)" \
          "la imagen es amd64; revisa 'platform: linux/amd64' en docker-compose.yml"
fi

# Prueba de velocidad: si la máquina emula (Mac con chip Apple), esto se dispara
# y conviene que el alumno lo sepa ANTES de culpar al simulador.
T0=$(date +%s%N)
awk 'BEGIN{s=0; for(i=0;i<3000000;i++) s+=i%7; print s}' >/dev/null 2>&1
T1=$(date +%s%N)
MS=$(( (T1-T0)/1000000 ))
if   [ "$MS" -lt 1200 ]; then c_ok   "Velocidad de CPU: ${MS} ms (normal, ejecución nativa)"
elif [ "$MS" -lt 4000 ]; then c_warn "Velocidad de CPU: ${MS} ms (lento; ¿Mac con chip Apple? Stonefish irá a tirones)"
else                          c_warn "Velocidad de CPU: ${MS} ms (MUY lento; casi seguro emulación. Activa Rosetta en Docker Desktop)"
fi

# Segunda pista de emulación, independiente del cronómetro: bajo QEMU/Rosetta la
# CPU declarada no es la del portátil. Un portátil viejo pero nativo da lento en
# la prueba de arriba y aquí sale limpio; así se distingue un caso del otro.
CPUMODEL=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)
case "$CPUMODEL" in
    *QEMU*|*Virtual*|*"Common KVM"*)
        c_warn "CPU declarada: '$CPUMODEL' (emulación x86 sobre otro chip; todo irá lento)" ;;
esac

CPUS=$(nproc 2>/dev/null || echo '?')
MEM=$(awk '/MemTotal/{printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null || echo '?')
c_ok "Recursos visibles: ${CPUS} CPU, ${MEM} GB RAM"
[ "${MEM%%.*}" -lt 4 ] 2>/dev/null && \
    c_warn "Menos de 4 GB de RAM: el stack submarino puede quedarse corto (sube la memoria en Docker Desktop > Settings > Resources)"
[ "$CPUS" -lt 2 ] 2>/dev/null && \
    c_warn "Solo ${CPUS} CPU visible: Stonefish y RViz irán a tirones (sube las CPU en Docker Desktop)"

# Memoria compartida: si es pequeña, el navegador del escritorio se cae solo.
SHM=$(df -m /dev/shm 2>/dev/null | awk 'NR==2{print $2}')
if [ -n "$SHM" ] && [ "$SHM" -ge 256 ]; then
    c_ok "/dev/shm: ${SHM} MB"
else
    c_bad "/dev/shm demasiado pequeño (${SHM:-?} MB)" \
          "falta 'shm_size: 512m'; arranca con docker compose, no con docker run"
fi

# Disco: 'cm' escribe en build/ y devel/ DENTRO del contenedor. Si el disco de
# Docker está lleno, catkin_make falla con errores crípticos del compilador.
LIBRE=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
if [ -z "$LIBRE" ]; then
    c_warn "No se pudo medir el espacio libre en disco"
elif [ "$LIBRE" -ge 3000 ]; then
    c_ok "Espacio libre en disco: $((LIBRE/1024)) GB"
elif [ "$LIBRE" -ge 1000 ]; then
    c_warn "Solo quedan $((LIBRE/1024)) GB libres: 'cm' puede fallar. Limpia con 'docker system prune'"
else
    c_bad "Disco casi lleno (${LIBRE} MB libres)" \
          "compilar fallará; desde tu ordenador: docker system prune -a"
fi

# -----------------------------------------------------------------------------
titulo "2. Usuario y entorno ROS"
# -----------------------------------------------------------------------------
# Lo que importa NO es quién lanza este test (con 'docker compose exec' siempre
# es root), sino que el ESCRITORIO corra como 'ubuntu' con uid 1000: de ahí
# depende que los ficheros que cree el alumno le salgan suyos en su disco.
UID_UBUNTU=$(id -u "$ALUMNO_USER" 2>/dev/null)
if [ "$UID_UBUNTU" = "1000" ]; then
    c_ok "Usuario '$ALUMNO_USER' existe con uid 1000"
else
    c_bad "El usuario '$ALUMNO_USER' no existe o no tiene uid 1000 (uid=${UID_UBUNTU:-ninguno})" \
          "el entrypoint no lo creó; revisa ENV USER=ubuntu en el Dockerfile"
fi

DUENO_VNC=$(ps -eo user,comm --no-headers 2>/dev/null | awk '$2=="Xtigervnc"{print $1; exit}')
if [ -z "$DUENO_VNC" ]; then
    c_bad "El servidor gráfico Xtigervnc no está corriendo" \
          "el escritorio no ha arrancado; ver sección 6"
elif [ "$DUENO_VNC" = "$ALUMNO_USER" ]; then
    c_ok "El escritorio corre como '$ALUMNO_USER' (no como root)"
else
    c_bad "El escritorio corre como '$DUENO_VNC', no como '$ALUMNO_USER'" \
          "en Linux tu código aparecerá como root en tu disco; falta ENV USER=ubuntu"
fi

[ -n "${CATKIN_WS:-}" ] && [ -d "$CATKIN_WS" ] && c_ok "CATKIN_WS = $CATKIN_WS" \
    || c_bad "CATKIN_WS sin definir o inexistente" "el entorno del curso no se ha cargado"

# Entorno INTERACTIVO real del alumno. Es la comprobación que caza la trampa del
# orden de sourcing: si el bloque del curso no queda el último en ~/.bashrc, el
# setup.bash de ROS reescribe ROS_PACKAGE_PATH y el workspace desaparece. Los
# alias siguen ahí (mismo fichero), así que el síntoma es "los atajos existen
# pero rospack no encuentra nada". Hay que lanzar un bash -i COMO 'ubuntu':
# hacerlo como root leería otro ~/.bashrc y no probaría nada.
RPP_INT=$(como_alumno_sh 'bash -ic "echo \$ROS_PACKAGE_PATH" 2>/dev/null' | tail -1)
case "$RPP_INT" in
    "${CATKIN_WS}/src"*)
        c_ok "ROS_PACKAGE_PATH del alumno empieza por el workspace" ;;
    *"${CATKIN_WS}/src"*)
        c_warn "El workspace está en ROS_PACKAGE_PATH pero NO el primero: '$RPP_INT'" ;;
    "")
        c_bad "El shell interactivo del alumno no tiene ROS_PACKAGE_PATH" \
              "el entorno del curso no se carga; revisa /etc/course_env.sh y ~/.bashrc" ;;
    *)
        c_bad "ROS_PACKAGE_PATH del alumno NO incluye el workspace" \
              "orden de sourcing roto (~/.bashrc pisa el entorno del curso); ver README" ;;
esac

# Los alias deben existir EN LA TERMINAL, no solo dentro del fichero: si el
# fichero se carga pero el bloque queda mal colocado, grep diría que sí y el
# alumno vería 'command not found'.
ALIAS_KO=0
for a in cw cm sw kobuki_sim sparus2 girona500; do
    como_alumno_sh "bash -ic 'type $a' >/dev/null 2>&1" || ALIAS_KO=$((ALIAS_KO+1))
done
[ "$ALIAS_KO" -eq 0 ] && c_ok "Los 6 atajos (cw, cm, sw, kobuki_sim, sparus2, girona500) responden en la terminal" \
    || c_bad "$ALIAS_KO atajos no existen en una terminal del alumno" \
             "/etc/course_aliases.sh no se está cargando"

# roscore falla con "Unable to contact my own server" si el nombre del
# contenedor no resuelve. Pasa con configuraciones de red raras del host.
if getent hosts "$(hostname)" >/dev/null 2>&1; then
    c_ok "El nombre del contenedor resuelve (roscore podrá arrancar)"
else
    c_bad "El nombre '$(hostname)' no resuelve a una IP" \
          "roscore dará 'Unable to contact my own server'; revisa /etc/hosts"
fi

# -----------------------------------------------------------------------------
titulo "3. Carpeta compartida con tu ordenador  (LO MÁS IMPORTANTE)"
# -----------------------------------------------------------------------------
STUDENT_DIR="${COURSE_CODE_DIR:-${CATKIN_WS}/src/student}"
if [ ! -d "$STUDENT_DIR" ]; then
    c_bad "NO existe $STUDENT_DIR" \
          "arrancaste con 'docker run' sin -v. Usa 'docker compose up -d'. TU CÓDIGO NO SE GUARDARÍA."
elif ! grep -q " ${STUDENT_DIR} " /proc/mounts 2>/dev/null; then
    c_bad "$STUDENT_DIR existe pero NO es una carpeta compartida" \
          "lo que escribas ahí se PERDERÁ al borrar el contenedor. Usa 'docker compose up -d'."
else
    c_ok "Carpeta compartida montada en $STUDENT_DIR"

    # Montaje de solo lectura: pasa si alguien añade ':ro' al volumes:.
    if grep " ${STUDENT_DIR} " /proc/mounts 2>/dev/null | awk '{print $4}' | grep -q '^ro,\|,ro,\|,ro$\|^ro$'; then
        c_bad "La carpeta compartida está montada en SOLO LECTURA" \
              "quita ':ro' del 'volumes:' de docker-compose.yml"
    fi

    # La escritura hay que probarla COMO 'ubuntu'. Hecha como root diría que sí
    # aunque el alumno no pudiera escribir: es el fallo clásico de Linux cuando
    # ./code pertenece a root en el disco del host.
    PRUEBA="$STUDENT_DIR/.selftest_$$"
    if como_alumno touch "$PRUEBA"; then
        rm -f "$PRUEBA" 2>/dev/null || como_alumno rm -f "$PRUEBA"
        c_ok "El usuario del escritorio puede escribir en ella (tus cambios se guardan en tu ordenador)"
    else
        c_bad "El usuario del escritorio NO puede escribir en la carpeta compartida" \
              "en Linux, desde tu ordenador: sudo chown -R 1000:1000 code"
    fi

    # Las tres subcarpetas de práctica: si falta alguna, 'docker compose up' se
    # lanzó sobre una carpeta 'code' vieja o creada a mano sin ellas.
    PL_KO=""
    for pl in PL0 PL1 PL2; do
        [ -d "$STUDENT_DIR/$pl" ] || PL_KO="$PL_KO $pl"
    done
    [ -z "$PL_KO" ] && c_ok "Las carpetas PL0, PL1 y PL2 existen dentro de la carpeta compartida" \
        || c_warn "Faltan subcarpetas:$PL_KO (créalas o vuelve a copiar 'code/' del repositorio)"

    # Si el alumno ya tiene paquetes, avisar de que están ahí (no es un fallo
    # que no los haya: puede ser la primera sesión).
    if find "$STUDENT_DIR" -mindepth 2 -maxdepth 3 -name package.xml >/dev/null 2>&1 \
       && [ -n "$(find "$STUDENT_DIR" -mindepth 2 -maxdepth 3 -name package.xml -print -quit 2>/dev/null)" ]; then
        c_ok "Hay al menos un paquete tuyo en la carpeta compartida"
    fi
fi

# Sin esto el alumno no puede compilar su propio nodo: es el chown final de la
# capa 8 del Dockerfile.
if [ "$(stat -c %U "$CATKIN_WS" 2>/dev/null)" = "$ALUMNO_USER" ] && como_alumno test -w "$CATKIN_WS"; then
    c_ok "El workspace pertenece a '$ALUMNO_USER' y es escribible ('cm' funcionará)"
else
    c_bad "El workspace no es escribible por '$ALUMNO_USER' (dueño: $(stat -c %U "$CATKIN_WS" 2>/dev/null))" \
          "'cm' fallará; falta el chown -R de la capa 8 del Dockerfile"
fi

# -----------------------------------------------------------------------------
titulo "4. Stack Kobuki — PL1 (robot con ruedas)"
# -----------------------------------------------------------------------------
for p in kobuki_node kobuki_driver kobuki_msgs kobuki_description \
         kobuki_gazebo kobuki_gazebo_plugins kobuki_keyop \
         yocs_cmd_vel_mux yocs_velocity_smoother; do
    rospack find "$p" >/dev/null 2>&1 && c_ok "Paquete $p" \
        || c_bad "Paquete $p no encontrado" "rospack no lo resuelve"
done

# kobuki_node no genera un ejecutable propio: se carga como nodelet (ver
# minimal.launch). Comprobar el .so es lo que de verdad indica que compiló.
[ -f "${CATKIN_WS}/devel/lib/libkobuki_nodelet.so" ] \
    && c_ok "Nodelet del driver (kobuki_node) compilado" \
    || c_bad "Falta libkobuki_nodelet.so" "el driver del Kobuki no compiló"

[ -f "${CATKIN_WS}/devel/lib/libgazebo_ros_kobuki.so" ] \
    && c_ok "Plugin de Gazebo del Kobuki compilado" \
    || c_bad "Falta libgazebo_ros_kobuki.so" "el modelo simulado no se moverá en Gazebo"

[ -f "${CATKIN_WS}/src/kobuki_desktop/kobuki_gazebo/launch/kobuki_playground.launch" ] \
    && c_ok "Launch de simulación kobuki_playground.launch presente" \
    || c_bad "Falta kobuki_playground.launch"

[ -f "${CATKIN_WS}/src/kobuki/kobuki_description/urdf/kobuki_standalone.urdf.xacro" ] \
    && c_ok "Modelo URDF del Kobuki presente" \
    || c_bad "Falta el URDF de kobuki_description"

command -v gzserver >/dev/null 2>&1 && c_ok "Gazebo instalado ($(gzserver --version 2>&1 | head -1))" \
    || c_bad "gzserver no encontrado" "no se puede simular el Kobuki sin robot físico"

# -----------------------------------------------------------------------------
titulo "5. Stack submarino — COLA2 + Stonefish"
# -----------------------------------------------------------------------------
for p in cola2_msgs cola2_lib_ros cola2_control cola2_nav cola2_safety \
         stonefish_ros cola2_stonefish sparus2_description girona500_description; do
    rospack find "$p" >/dev/null 2>&1 && c_ok "Paquete $p" \
        || c_bad "Paquete $p no encontrado"
done
[ -f /usr/local/lib/libStonefish.so ] && c_ok "libStonefish.so instalada" \
    || c_bad "Falta libStonefish.so"
ls /usr/local/lib/libcola2_*.so >/dev/null 2>&1 && \
    c_ok "Librerías cola2_lib instaladas ($(ls /usr/local/lib/libcola2_*.so | wc -l))" \
    || c_bad "Faltan las librerías de cola2_lib"

# python-is-python3: sin esto ~20 nodos de COLA2 mueren en bucle.
command -v python >/dev/null 2>&1 && c_ok "'python' enlazado a $(python --version 2>&1)" \
    || c_bad "No existe /usr/bin/python" "los nodos Python de COLA2 no arrancarán"

# El nodo de teleoperación es C++ en este core; los launch deben pedirlo sin .py
[ -x "${CATKIN_WS}/devel/lib/cola2_control/teleoperation_node" ] \
    && c_ok "teleoperation_node (C++) compilado" || c_bad "Falta teleoperation_node"
if grep -rq 'type="teleoperation_node.py"' "${CATKIN_WS}/src/cola2_stonefish/launch/" 2>/dev/null; then
    c_bad "Los launch aún piden teleoperation_node.py" "faltará la teleoperación por teclado"
else
    c_ok "Launch alineados con el nodo C++ de teleoperación"
fi

# Calidad gráfica: 'high' no compila shaders sin GPU.
if grep -rq 'graphics_quality" default="low"' "${CATKIN_WS}/src/cola2_stonefish/launch/" 2>/dev/null; then
    c_ok "graphics_quality por defecto en 'low' (necesario sin GPU)"
else
    c_warn "graphics_quality no está en 'low'; si no se dibuja nada, es esto"
fi

# Los 4 launch deben existir Y su escenario .scn resolverse: un launch cuyo .scn
# falta arranca, tarda 60 s y muere sin decir por qué.
LAUNCH_KO=0; SCN_KO=""
for l in sparus2_tank_simulation girona500_tank_simulation \
         girona500_valve_turning_simulation girona500_windturbine; do
    F="${CATKIN_WS}/src/cola2_stonefish/launch/${l}.launch"
    [ -f "$F" ] || { LAUNCH_KO=$((LAUNCH_KO+1)); continue; }
    for s in $(grep -o '[A-Za-z0-9_]*\.scn' "$F" 2>/dev/null | sort -u); do
        find "${CATKIN_WS}/src/cola2_stonefish" -name "$s" 2>/dev/null | grep -q . || SCN_KO="$SCN_KO $s"
    done
done
[ "$LAUNCH_KO" -eq 0 ] && c_ok "Los 4 launch de escenarios están presentes" \
    || c_bad "$LAUNCH_KO launch de cola2_stonefish no existen"
[ -z "$SCN_KO" ] && c_ok "Todos los escenarios .scn referenciados existen" \
    || c_warn "Escenarios .scn no encontrados:$SCN_KO (recuerda: girona500_eca5emicro depende de un repo no público)"

# -----------------------------------------------------------------------------
titulo "6. Escritorio en el navegador (http://localhost:6080)"
# -----------------------------------------------------------------------------
# Esta sección responde a la pregunta más frecuente: "abro localhost:6080 y no
# sale nada". Separa el problema en dos: si aquí está todo OK, el contenedor
# sirve el escritorio y el problema está en el puerto o el navegador del alumno.
# supervisorctl solo funciona para root: su socket es de root, y lanzado por
# 'ubuntu' (o sea, desde una terminal del escritorio) escupe un traceback. Si no
# se puede usar, se mira lo mismo por los procesos, que cualquiera puede ver.
SUPER_OK=0
supervisorctl status 2>/dev/null | grep -qE 'RUNNING|STOPPED|EXITED|FATAL' && SUPER_OK=1

servicio() {   # $1 = nombre en supervisord, $2 = patrón del proceso, $3 = para qué sirve
    if [ "$SUPER_OK" -eq 1 ]; then
        EST=$(supervisorctl status "$1" 2>/dev/null | awk '{print $2}')
        [ "$EST" = "RUNNING" ] && c_ok "Servicio '$1' en marcha ($3)" \
            || c_bad "Servicio '$1' en estado ${EST:-desconocido} ($3)" \
                     "el escritorio no se verá; desde tu ordenador: docker compose restart"
    elif pgrep -f "$2" >/dev/null 2>&1; then
        c_ok "Servicio '$1' en marcha ($3)"
    else
        c_bad "El proceso de '$1' no existe ($3)" \
              "el escritorio no se verá; desde tu ordenador: docker compose restart"
    fi
}
servicio vnc   Xtigervnc  "servidor gráfico"
servicio novnc websockify "puente al navegador"

# El programa del curso es de un solo disparo: sale con 0 y se queda EXITED.
if [ "$SUPER_OK" -eq 1 ]; then
    EST=$(supervisorctl status course-desktop-setup 2>/dev/null | awk '{print $2}')
    case "$EST" in
        EXITED|RUNNING|STOPPED) c_ok "Preparación del escritorio ejecutada (estado: $EST)" ;;
        FATAL|BACKOFF)          c_bad "La preparación del escritorio falló (estado: $EST)" \
                                      "mira /var/log/course_desktop_setup.log" ;;
        *)                      c_warn "Programa 'course-desktop-setup' no registrado en supervisord" ;;
    esac
elif [ -s /var/log/course_desktop_setup.log ]; then
    if grep -qi 'error\|no such file\|denied' /var/log/course_desktop_setup.log 2>/dev/null; then
        c_bad "Errores en la preparación del escritorio" "mira /var/log/course_desktop_setup.log"
    else
        c_ok "Preparación del escritorio ejecutada sin errores"
    fi
else
    c_warn "No hay registro de la preparación del escritorio (/var/log/course_desktop_setup.log)"
fi

# ¿Hay alguien sirviendo el puerto 80 dentro del contenedor? Es lo que el
# compose publica en 127.0.0.1:6080.
if command -v curl >/dev/null 2>&1 && curl -s -o /dev/null --max-time 5 http://localhost:80/ 2>/dev/null; then
    c_ok "El escritorio responde dentro del contenedor -> abre http://localhost:6080"
else
    c_bad "Nadie sirve el puerto 80 dentro del contenedor" \
          "localhost:6080 no cargará; revisa los servicios vnc/novnc de arriba"
fi

# El display, probado como 'ubuntu': root NO puede abrirlo (la cookie de
# X está en /home/ubuntu/.Xauthority), así que probarlo como root daría un
# falso aviso y taparía un escritorio realmente caído.
if como_alumno_sh 'DISPLAY=:1 xdpyinfo >/dev/null 2>&1'; then
    DIM=$(como_alumno_sh 'DISPLAY=:1 xdpyinfo 2>/dev/null' | awk '/dimensions:/{print $2}')
    c_ok "Display :1 accesible (${DIM:-?})"
    GLR=$(como_alumno_sh 'DISPLAY=:1 glxinfo 2>/dev/null' | awk -F': ' '/OpenGL renderer/{print $2}')
    GLV=$(como_alumno_sh 'DISPLAY=:1 glxinfo 2>/dev/null' | awk -F': ' '/OpenGL core profile version/{print $2}')
    if [ -n "$GLV" ]; then
        c_ok "OpenGL: ${GLV%% *} (${GLR})"
        case "$GLR" in
            *llvmpipe*|*softpipe*|*swrast*)
                c_warn "Render por software: Stonefish funcionará, pero lento. Es lo esperado aquí." ;;
        esac
    else
        c_warn "No se pudo consultar OpenGL (glxinfo no disponible)"
    fi
else
    c_bad "El servidor gráfico :1 no responde" \
          "el escritorio no ha terminado de arrancar (espera 15 s) o murió: docker compose restart"
fi

# El escritorio del ALUMNO, no el de quien lanza el test.
DESK="${ALUMNO_HOME}/Desktop"
if [ -d "$DESK" ]; then
    NOEXEC=$(find "$DESK" -name '*.desktop' ! -perm -u+x 2>/dev/null | wc -l)
    [ "$NOEXEC" -eq 0 ] && c_ok "Lanzadores del escritorio ejecutables (sin aviso de 'Untrusted')" \
        || c_bad "$NOEXEC lanzadores sin permiso de ejecución" "saldrá 'Untrusted application launcher'"
    if [ -f "$DESK/codium.desktop" ]; then
        grep -q -- '--no-sandbox' "$DESK/codium.desktop" \
            && c_ok "VSCodium con --no-sandbox (necesario en Docker)" \
            || c_bad "VSCodium sin --no-sandbox" "no abrirá al hacer doble clic"
    fi
    if [ -e "$DESK/MY_CODE" ]; then
        [ -d "$DESK/MY_CODE" ] && c_ok "Acceso 'MY_CODE' en el escritorio" \
            || c_bad "El enlace MY_CODE está roto" "mira /var/log/course_desktop_setup.log"
    else
        c_warn "No hay enlace 'MY_CODE' en el escritorio (el alumno tendrá que navegar a src/student)"
    fi
else
    c_bad "No existe $DESK" "el escritorio del usuario del curso no se ha creado"
fi

# -----------------------------------------------------------------------------
titulo "7. Ficheros del curso (finales de línea)"
# -----------------------------------------------------------------------------
# Un clon en Windows con core.autocrlf=true mete \r y rompe los scripts.
CRLF=0
for f in /etc/course_aliases.sh /etc/course_env.sh /usr/local/bin/selftest \
         /usr/local/bin/course_desktop_setup.sh; do
    [ -f "$f" ] || continue
    grep -qU $'\r' "$f" 2>/dev/null && CRLF=$((CRLF+1))
done
[ "$CRLF" -eq 0 ] && c_ok "Sin retornos de carro de Windows (CRLF) en los scripts del curso" \
    || c_bad "$CRLF ficheros con CRLF" "reconstruye la imagen; revisa .gitattributes"

# -----------------------------------------------------------------------------
if [ "$MODO_COMPLETO" -eq 1 ]; then
titulo "8. Prueba de vuelo — Kobuki simulado en marcha (esto tarda ~1 min)"
# -----------------------------------------------------------------------------
# Lo único que las comprobaciones estáticas no pueden ver: que Gazebo arranque
# de verdad, que el plugin del Kobuki se cargue y que /odom y /joint_states
# circulen. Se lanza gzserver SIN interfaz gráfica (gzclient): la prueba mide
# física y topics, no dibujo, así que no hace falta esperar al display.
#
# Si ya hay un roscore, esta prueba NO se ejecuta. Es deliberado: la prueba
# termina matando gzserver y el resto de procesos lanzados, y si el alumno
# tiene su simulación abierta se la cargaríamos por sorpresa. Además, arrancar
# encima de una sesión ajena da resultados que no significan nada.
    limpiar() {
        como_alumno_sh 'pkill -f gzserver; pkill -f robot_state_publisher; pkill -f spawn_model; pkill -f rosmaster' >/dev/null 2>&1
        sleep 1
    }

    if como_alumno_sh 'source /etc/course_env.sh; rostopic list >/dev/null 2>&1'; then
        c_warn "Ya tienes ROS en marcha: prueba de vuelo OMITIDA (cierra tu simulación, o reinicia el contenedor, y repite)"
        MODO_COMPLETO=2   # marca 'omitida' para el resumen
    else

    trap 'limpiar' EXIT INT TERM

    como_alumno_sh 'source /etc/course_env.sh; nohup roscore >/tmp/st_roscore.log 2>&1 &'
    for i in $(seq 1 20); do
        como_alumno_sh 'source /etc/course_env.sh; rostopic list >/dev/null 2>&1' && break
        sleep 1
    done
    if como_alumno_sh 'source /etc/course_env.sh; rostopic list >/dev/null 2>&1'; then
        c_ok "roscore arrancado"
    else
        c_bad "roscore no arranca" "mira /tmp/st_roscore.log"
    fi

    KOBUKI_WORLD="${CATKIN_WS}/src/kobuki_desktop/kobuki_gazebo/worlds/playground.world"
    como_alumno_sh "source /etc/course_env.sh; nohup rosrun gazebo_ros gzserver '$KOBUKI_WORLD' >/tmp/st_gzserver.log 2>&1 &"
    for i in $(seq 1 30); do
        como_alumno_sh 'source /etc/course_env.sh; rosservice list 2>/dev/null' | grep -q '/gazebo/spawn_urdf_model' && break
        sleep 1
    done
    if como_alumno_sh 'source /etc/course_env.sh; rosservice list 2>/dev/null' | grep -q '/gazebo/spawn_urdf_model'; then
        c_ok "gzserver arrancado (física del Kobuki disponible)"
    else
        c_bad "gzserver no arranca o no publica sus servicios" "mira /tmp/st_gzserver.log"
    fi

    como_alumno_sh "source /etc/course_env.sh; nohup roslaunch \$(rospack find kobuki_gazebo)/launch/includes/robot.launch.xml >/tmp/st_spawn.log 2>&1 &"
    for i in $(seq 1 30); do
        como_alumno_sh 'source /etc/course_env.sh; rostopic list 2>/dev/null' | grep -qx '/odom' && break
        sleep 1
    done
    TOPICS=$(como_alumno_sh 'source /etc/course_env.sh; rostopic list 2>/dev/null')
    for t in /odom /joint_states /mobile_base/commands/velocity; do
        echo "$TOPICS" | grep -qx "$t" && c_ok "Topic $t publicado" \
            || c_bad "Falta el topic $t" "el modelo simulado no se cargó; mira /tmp/st_spawn.log"
    done

    if echo "$TOPICS" | grep -qx '/odom'; then
        como_alumno_sh 'source /etc/course_env.sh; timeout 8 rostopic hz /odom 2>&1' | grep -q 'average rate' \
            && c_ok "/odom publica datos con el simulador en marcha" \
            || c_warn "/odom existe pero no se pudo medir su frecuencia en 8 s"
    fi

    limpiar
    trap - EXIT INT TERM
    c_ok "Simulación de prueba cerrada y entorno limpio"
    fi   # fin del 'else' de "ya había ROS en marcha"
fi

# -----------------------------------------------------------------------------
printf '\n\033[1m=== RESUMEN ===\033[0m\n'
printf '  Correctos: %s   Avisos: %s   Fallos: %s\n' "$OK" "$WARN" "$FAIL"
[ "$MODO_COMPLETO" -eq 0 ] && \
    printf '  (prueba a fondo con simulador incluido: selftest --completo)\n'
[ "$MODO_COMPLETO" -eq 2 ] && \
    printf '  \033[33mLa prueba de vuelo se omitió: cierra ROS y repite.\033[0m\n'
if [ "$FAIL" -eq 0 ]; then
    printf '\n  \033[32mEntorno correcto. Puedes empezar a trabajar.\033[0m\n\n'
    exit 0
else
    printf '\n  \033[31mHay %s problema(s):\033[0m\n' "$FAIL"
    for f in "${FALLOS[@]}"; do printf '    - %s\n' "$f"; done
    printf '\n  Mira la sección "Si algo falla" del README.\n'
    printf '  Si escribes al profesor, pega ESTA salida entera.\n\n'
    exit 1
fi
