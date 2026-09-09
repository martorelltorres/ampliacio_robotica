#!/bin/bash
# =============================================================================
#  Arreglos del escritorio que HAY QUE HACER EN CADA ARRANQUE
# =============================================================================
#  Se ejecuta desde supervisord (ver /etc/supervisor/conf.d/zz-course-desktop.conf),
#  NO desde el build. El motivo: el /entrypoint.sh de la imagen base RECREA
#  ~/Desktop entero en cada arranque, asi que cualquier arreglo horneado en una
#  capa del Dockerfile lo machacaria el propio entrypoint al arrancar.
#
#  supervisord se lanza al final del entrypoint (exec /bin/tini -- supervisord),
#  o sea DESPUES de que los .desktop existan. Aun asi se espera, por si acaso.
# =============================================================================
set -u

USER_NAME="${COURSE_USER:-ubuntu}"
HOME_DIR="/home/${USER_NAME}"
DESK="${HOME_DIR}/Desktop"
STUDENT_DIR="${COURSE_CODE_DIR:-${CATKIN_WS:-${HOME_DIR}/catkin_ws}/src/student}"

# Esperar a que el entrypoint haya creado el escritorio.
for _ in $(seq 1 60); do
    [ -d "$DESK" ] && ls "$DESK"/*.desktop >/dev/null 2>&1 && break
    sleep 1
done
[ -d "$DESK" ] || { echo "AVISO: $DESK no existe; nada que hacer."; exit 0; }

# -----------------------------------------------------------------------------
# 1. Lanzadores de confianza  ("Untrusted application launcher")
#
# Caja considera de confianza un .desktop cuando se cumplen DOS cosas:
#   (a) empieza por el shebang '#!/usr/bin/env xdg-open'  -> el entrypoint YA
#       lo escribe, esta parte esta bien;
#   (b) tiene bit de ejecucion.
#
# La (b) falla porque el entrypoint hace:
#       chmod +x "$HOME/Desktop/*.desktop"
# con el glob ENTRE COMILLAS. Bash lo trata como un nombre de fichero literal,
# el chmod da "No such file or directory" y los iconos se quedan en 644. Por eso
# el alumno recibe el dialogo "Untrusted application launcher" en cada icono.
# -----------------------------------------------------------------------------
chmod +x "$DESK"/*.desktop 2>/dev/null || true
chown "${USER_NAME}:${USER_NAME}" "$DESK"/*.desktop 2>/dev/null || true
echo "OK: $(ls -1 "$DESK"/*.desktop 2>/dev/null | wc -l) lanzadores marcados como ejecutables."

# -----------------------------------------------------------------------------
# 2. VSCodium: --no-sandbox
#
# El sandbox de Chromium necesita crear user namespaces sin privilegios, cosa
# que el contenedor no puede. Sin este flag, VSCodium NO ABRE: muere con
#   Failed to move to new namespace: PID namespaces supported, Network
#   namespace supported, but failed: errno = Operation not permitted
#   FATAL ... zygote_host_impl_linux.cc ... Check failed
# y como el icono no deja terminal a la vista, el alumno solo ve que "no pasa
# nada" al hacer doble clic.
#
# La entrada del menu de aplicaciones (/usr/share/applications) se parchea en el
# Dockerfile, que esa no la recrea el entrypoint. Aqui va la del escritorio.
# -----------------------------------------------------------------------------
if [ -f "$DESK/codium.desktop" ] && ! grep -q -- '--no-sandbox' "$DESK/codium.desktop"; then
    sed -i 's|^Exec=/usr/share/codium/codium|Exec=/usr/share/codium/codium --no-sandbox|' \
        "$DESK/codium.desktop"
    echo "OK: --no-sandbox anadido a codium.desktop del escritorio."
fi

# -----------------------------------------------------------------------------
# 3. Acceso directo a la carpeta compartida con el ordenador del alumno
#
# 'src/student' es el bind mount de ./code del docker-compose: lo que se
# escribe ahi vive en el disco del alumno y sobrevive a borrar el contenedor.
# Se deja un enlace en el escritorio porque, si no, no lo encuentra: el resto
# del workspace esta dentro de la imagen y NO se guarda.
# -----------------------------------------------------------------------------
if [ -d "$STUDENT_DIR" ] && [ ! -e "$DESK/MY_CODE" ]; then
    ln -s "$STUDENT_DIR" "$DESK/MY_CODE" 2>/dev/null \
        && chown -h "${USER_NAME}:${USER_NAME}" "$DESK/MY_CODE" 2>/dev/null \
        && echo "OK: enlace MY_CODE -> $STUDENT_DIR"
fi

echo "Escritorio del curso preparado."
