# --- Atajos del curso (ROS Noetic) ---
# Se instala en /etc/course_aliases.sh y se carga desde /etc/bash.bashrc,
# asi que funciona para cualquier usuario de la imagen, no solo para root.
# Por eso las rutas salen de $CATKIN_WS / $COURSE_CODE_DIR y no estan fijas.
: "${CATKIN_WS:=/home/ubuntu/catkin_ws}"
: "${COURSE_CODE_DIR:=${CATKIN_WS}/src/student}"
export CATKIN_WS COURSE_CODE_DIR

alias cw='cd "$CATKIN_WS"'
alias cm='cd "$CATKIN_WS" && catkin_make -DCMAKE_BUILD_TYPE=Release'
alias sw='source "$CATKIN_WS/devel/setup.bash"'

# OJO: no llamar a esto 'rosclean'. 'rosclean' YA es una herramienta de ROS
# (limpia los logs) y un alias la dejaria inaccesible, con el efecto sorpresa
# de borrar el workspace compilado a quien siga un tutorial cualquiera.
alias wsclean='rm -rf "$CATKIN_WS/build" "$CATKIN_WS/devel"'

# Atajos a cada carpeta de practica dentro de la carpeta compartida con el
# ordenador del alumno. Es donde catkin_create_pkg debe crear el paquete de
# cada practica (pl0_cognom, pl1_cognom, pl2_cognom).
alias cpl0='cd "$COURSE_CODE_DIR/PL0"'
alias cpl1='cd "$COURSE_CODE_DIR/PL1"'
alias cpl2='cd "$COURSE_CODE_DIR/PL2"'

# --- PL1: Kobuki (robot de traccion diferencial) -----------------------------
# El Kobuki fisico se conecta solo; sin el, este alias levanta su modelo
# simulado en Gazebo con la misma interfaz ROS (/odom, /mobile_base/commands/
# velocity, /joint_states...). El codigo de la practica no cambia entre las
# dos vias.
alias kobuki_sim='roslaunch kobuki_gazebo kobuki_playground.launch'
alias kobuki_keyop='roslaunch kobuki_keyop keyop.launch'

# --- PL2: COLA2 + Stonefish (vehiculo submarino autonomo) --------------------
# Estos launch arrancan TODO (simulador + pila COLA2) en una sola terminal.
# Tardan ~60 s en levantar todos los nodos.
#
# La calidad grafica va a 'low' por defecto: el escritorio no tiene GPU y con
# 'high' los shaders de Stonefish no compilan (ver README). Con GPU real:
#   sparus2 graphics_quality:=high
alias sparus2='roslaunch cola2_stonefish sparus2_tank_simulation.launch'
alias girona500='roslaunch cola2_stonefish girona500_tank_simulation.launch'
alias girona500_valve='roslaunch cola2_stonefish girona500_valve_turning_simulation.launch'
alias girona500_wind='roslaunch cola2_stonefish girona500_windturbine.launch'
