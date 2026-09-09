# Entorn de pràctiques — Ampliació de Robòtica (UIB)

Imatge Docker **completa i llesta per a l'aula**: un escriptori Linux amb ROS Noetic que
s'obre **al navegador**, amb els simuladors de les tres pràctiques ja compilats. Funciona
igual a Windows, macOS i Linux.

---

## Què porta dins

Base `tiryoh/ros-desktop-vnc:noetic` → escriptori MATE per navegador (noVNC), idèntic als
tres sistemes operatius. Tres stacks, un per pràctica de laboratori:

### PL0 — Introducció a ROS

Fa servir `turtlesim` i les eines estàndard de ROS Noetic (`rqt_graph`, `rqt_plot`, `rosbag`,
`rviz`...), ja incloses a la imatge base. No necessita res addicional.

### PL1 — Odometria en robots amb rodes (Kobuki)

| Component | Què és |
|---|---|
| `kobuki`, `kobuki_core`, `kobuki_msgs` | Driver ROS del Kobuki (`kobuki_node`, `kobuki_keyop`) |
| `kobuki_desktop` | Model simulat a Gazebo, mateixa interfície ROS que el robot físic |
| `yocs_cmd_vel_mux`, `yocs_velocity_smoother` | Multiplexatge i suavitzat de velocitat que fa servir el driver |

### PL2 — Navegació per estima submarina (COLA2 + Stonefish)

| Component | Què és |
|---|---|
| `cola2_lib` | Biblioteca C++ base del SRV (compilada des del codi font) |
| `Stonefish` | Simulador submarí: dinàmica amb Bullet Physics, sensors i render OpenGL |
| `cola2_msgs`, `cola2_lib_ros` | Missatges i utilitats ROS de COLA2 |
| `cola2_core` | Control, navegació, seguretat, log, comms i simulació |
| `sparus2_description`, `cola2_sparus2` | Vehicle **SparusII** |
| `girona500_description`, `cola2_girona500` | Vehicle **Girona500** |
| `stonefish_ros`, `cola2_stonefish` | Pont ROS ↔ Stonefish i els escenaris |

Tots els repositoris de codi font (COLA2/Stonefish i Kobuki) van fixats a **commit**, no a
tag, perquè dues construccions separades en el temps donin exactament la mateixa imatge.

## Estructura del repositori

```
ampliacio_robotica/
├── docker-compose.yml           # el que fan servir els ALUMNES per arrencar
├── code/                        # ← EL TEU CODI VA AQUÍ (es desa al teu ordinador)
│   ├── PL0/                     #   pràctica PL0 — Introducció a ROS
│   ├── PL1/                     #   pràctica PL1 — Odometria (Kobuki)
│   └── PL2/                     #   pràctica PL2 — Navegació per estima (COLA2)
│
├── INSTALLACIO.md                # guia d'instal·lació pas a pas (català)
└── docker/                       # tot el que construeix la imatge
    ├── Dockerfile.ros_base       # recepta de la imatge, capes numerades
    ├── requirements_py38.txt     # dependències Python, versions fixades
    ├── course_aliases.sh         # dreceres → /etc/course_aliases.sh
    ├── course_selftest.sh        # autotest → 'selftest' dins la imatge
    └── course_desktop_setup.sh   # arranjaments de l'escriptori, a CADA arrencada
```

`code/` és l'única carpeta que persisteix fora de la imatge: cada subcarpeta `PL0/`, `PL1/`
i `PL2/` és on l'alumne crea el seu propi paquet catkin per a aquella pràctica
(`pl0_cognom`, `pl1_cognom`, `pl2_cognom`). Cap stack no porta ja un paquet de curs
precuinat: els tres enunciats demanen explícitament que l'alumne creï el seu amb
`catkin_create_pkg`.

---

# Guia de l'alumne

## El que necessites

- **Docker Desktop** (Windows i macOS) o **Docker Engine** (Linux) — <https://docs.docker.com/get-started/get-docker/>
- Un navegador. Res més: ROS, els simuladors i l'escriptori van dins la imatge.
- Uns **12 GB de disc lliure**.

> **Descarrega-la a casa i amb temps.** Trenta descàrregues simultànies el primer dia de
> classe no acaben bé.

Per a la instal·lació completa pas a pas als tres sistemes, amb els comandes exactes, vegeu
**[INSTALLACIO.md](INSTALLACIO.md)**. El resum:

**Windows:** Docker Desktop amb backend **WSL2**. Posa la carpeta de treball en una ruta
normal (`C:\Users\el_teu_usuari\...`), **no** en una unitat de xarxa ni a OneDrive: la
carpeta compartida hi falla.

**macOS amb xip Apple (M1/M2/M3/M4):** a Docker Desktop → *Settings* → *General*, activa
**"Use Rosetta for x86/amd64 emulation"**. Sense això va molt més lent. No has d'editar ni
descomentar res.

## Arrencar i tancar el contenidor

Tots els comandes s'executen **des de la carpeta `ampliacio_robotica/`**, a la terminal del
teu sistema (PowerShell, Terminal o la que facis servir).

```bash
docker compose up -d          # arrencar (en segon pla)
```

Després obre **<http://localhost:6080>** al navegador: allà hi ha l'escriptori.

```bash
docker compose down           # tancar i esborrar el contenidor
docker compose stop           # només aturar-lo (conserva l'estat intern)
docker compose start          # tornar a arrencar-lo després d'un 'stop'
docker compose logs -f        # veure l'arrencada (Ctrl-C per sortir)
docker compose ps             # està funcionant?
```

**`docker compose down` no esborra el teu codi**: el que hi ha a `code/` és al teu disc, no
dins del contenidor. Vegeu la secció següent.

> ### ⚠ No facis servir `docker run`
>
> És l'error més freqüent. `docker run` **no munta la carpeta compartida**, així que el teu
> codi no es desa i desapareix en esborrar el contenidor. També se salta el `shm_size`, i
> aleshores el navegador de l'escriptori es tanca sol.
>
> Fes servir sempre `docker compose up -d`. El fitxer `docker-compose.yml` ja s'encarrega
> del volum, el port, la memòria compartida i la plataforma.
>
> Si veus `port is already allocated`, és que ja tens un contenidor aixecat. Comprova qui
> ocupa el port amb `docker ps` i fes servir el que ja hi ha.

## Com s'intercanvien els fitxers amb el teu ordinador

Aquesta és la part important i convé entendre-la bé.

```
   EL TEU ORDINADOR                            DINS DEL CONTENIDOR
   ────────────────                            ───────────────────
   ampliacio_robotica/code/       <══════>     /home/ubuntu/catkin_ws/src/student
     ├── PL0/                   (sincronitzat    ├── PL0/
     ├── PL1/                    a l'instant,    ├── PL1/
     └── PL2/                    en tots dos     └── PL2/
                                   sentits)
```

- **Tot el que escriguis a `code/` es veu dins del contenidor**, i a l'inrevés. No cal
  copiar res: és la mateixa carpeta vista des de dos llocs.
- **És l'únic que sobreviu.** La resta del sistema de fitxers del contenidor viu dins la
  imatge i **es perd** amb `docker compose down`.
- Pots editar amb el teu editor de sempre (VS Code, etc.) des del teu ordinador, o amb
  VSCodium dins de l'escriptori. Tant se val: és el mateix fitxer.

Dins de l'escriptori tens l'enllaç **`MY_CODE`** que porta directament a aquesta carpeta.

**Ull amb la ruta:** la carpeta apareix a `catkin_ws/src/`**`student`**`/`, no directament a
`catkin_ws/src/`. És a propòsit: `src/` conté també els paquets de Kobuki i COLA2, i muntar
la teva carpeta al damunt els taparia tots.

Cada pràctica té la seva subcarpeta (`code/PL0/`, `code/PL1/`, `code/PL2/`). Dins de cadascuna
crees el teu paquet catkin amb `catkin_create_pkg` (vegeu l'enunciat de cada pràctica) —
catkin troba paquets a qualsevol nivell de `src/`, així que no cal que estiguin directament
sota `src/`.

> **Linux:** no esborris la carpeta `code/`. Si no existeix en arrencar, Docker la crea com a
> `root` i no hi podràs escriure. Si et passa: `sudo chown -R 1000:1000 code`

## Comprova que tot funciona

Abans de donar per fet que alguna cosa està trencada, executa l'autotest. És el **mateix
comande a Windows, macOS i Linux**:

```bash
docker compose exec ros-dev selftest
```

O, des d'una terminal dins de l'escriptori, simplement:

```bash
selftest
```

Revisa la plataforma, el rendiment, l'usuari, la carpeta compartida, els stacks de Kobuki i
COLA2, l'escriptori del navegador i els finals de línia. Acaba amb un resum:

```
=== RESUMEN ===
  Correctos: 40   Avisos: 1   Fallos: 0

  Entorno correcto. Puedes empezar a trabajar.
```

Si hi ha fallades, les llista amb la secció on van sortir, la causa i què fer. Executa'l
**sempre** abans de demanar ajuda, i enganxa'n la sortida sencera si has de preguntar.

### Prova a fons, amb el robot en marxa

L'anterior comprova que tot *hi és*. Si vols comprovar que tot *funciona*, hi ha una prova
que arrenca de debò el simulador del Kobuki (triga un minut):

```bash
docker compose exec ros-dev selftest --completo
```

Afegeix una secció 8 que aixeca `roscore` i Gazebo amb el model del Kobuki, i verifica que
hi circulen `/odom`, `/joint_states` i `/mobile_base/commands/velocity`. En acabar ho tanca
tot.

> Si ja tens ROS en marxa, aquesta secció **se salta** en comptes de matar-te la simulació.
> Tanca-la i repeteix si la vols.

## Dreceres de la terminal de l'escriptori

| Àlies | Què fa |
|---|---|
| `cw` | anar al workspace |
| `cm` | compilar el workspace (Release) |
| `sw` | recarregar `devel/setup.bash` |
| `wsclean` | esborrar `build/` i `devel/` |
| `selftest` | autotest de l'entorn |
| `cpl0` / `cpl1` / `cpl2` | anar a `code/PL0`, `code/PL1` o `code/PL2` |
| `kobuki_sim` | **PL1**: model del Kobuki a Gazebo |
| `kobuki_keyop` | **PL1**: teleoperació per teclat |
| `sparus2` | **PL2**: SparusII a la piscina |
| `girona500` | **PL2**: Girona500 a la piscina |
| `girona500_valve` | **PL2**: Girona500, gir de vàlvula |
| `girona500_wind` | **PL2**: Girona500, aerogenerador |

> L'àlies de neteja es diu `wsclean` i **no** `rosclean`: `rosclean` ja és una eina de ROS i
> tapar-la amb un àlies que fa `rm -rf` és un parany.

## PL0 — Introducció a ROS

No necessita cap àlies del curs: és `turtlesim` i les eines estàndard de ROS. El teu paquet
(`pl0_cognom`) va dins de `code/PL0/`. Segueix l'enunciat de la pràctica.

## PL1 — Odometria en robots amb rodes (Kobuki)

Si no tens un Kobuki físic connectat, aixeca'n el model simulat:

```bash
kobuki_sim
```

Obre Gazebo amb el Kobuki en un món buit. Les dues vies (robot físic o simulat) exposen la
**mateixa interfície ROS**:

| Topic / interfície | Tipus | Sentit |
|---|---|---|
| `/odom` | `nav_msgs/Odometry` | el driver **publica** |
| `/mobile_base/commands/velocity` | `geometry_msgs/Twist` | l'alumne **publica** |
| `/mobile_base/sensors/imu_data` | `sensor_msgs/Imu` | el driver **publica** |
| `/joint_states` | `sensor_msgs/JointState` | el driver **publica** |
| `/mobile_base/commands/reset_odometry` | `std_msgs/Empty` | l'alumne **publica** |
| `/mobile_base/events/bumper` | `kobuki_msgs/BumperEvent` | el driver **publica** |

El teu paquet (`pl1_cognom`) va dins de `code/PL1/`. `kobuki_node` no exposa cap executable
propi: es carrega com a *nodelet* (vegeu `roslaunch kobuki_node minimal.launch` per al robot
físic). Segueix l'enunciat de la pràctica per al detall del model cinemàtic i de
l'experiment de caracterització de deriva.

## PL2 — Navegació per estima submarina (COLA2 + Stonefish)

Aquí **n'hi ha prou amb una sola terminal**: el launch aixeca el simulador i tota la pila
COLA2.

```bash
sparus2          # o girona500, girona500_valve, girona500_wind
```

Triga **~60 segons** a aixecar els 33 nodes. Paciència abans de donar res per trencat.

Quan estigui llest veuràs ~74 topics sota `/sparus2/...` (o `/girona500/...`): navegació,
control, seguretat, thrusters i sensors. El teu paquet (`pl2_cognom`) va dins de `code/PL2/`.
La pràctica treballa principalment sobre un rosbag de dades reals o simulades que et
facilitarà el professorat; el simulador serveix per explorar la interfície de topics de COLA2
abans de programar l'integrador de dead reckoning.

### Sobre els gràfics: anirà lent, i és normal

L'escriptori **no té GPU**. Mesa lliura OpenGL 4.5 per `llvmpipe`, que és un ratserizador
**per programari**. Stonefish arrenca i simula bé, però **el dibuixat és lent**. La física va
a velocitat nominal, així que per practicar control i navegació serveix perfectament.

Per això la qualitat gràfica va en `low` per defecte. Amb `high` els shaders no arriben ni a
compilar i no es dibuixa res. Si tens una GPU de debò i ho vols provar:

```bash
roslaunch cola2_stonefish sparus2_tank_simulation.launch graphics_quality:=high
```

## Si alguna cosa falla

Executa primer `selftest`. I si no, busca aquí el símptoma:

| Símptoma | Causa i solució |
|---|---|
| `port is already allocated` | Ja tens un contenidor amunt. `docker ps` per veure quin; fes servir aquest. |
| No veig els meus fitxers dins del contenidor | Has arrencat amb `docker run` en comptes de `docker compose up -d`. I recorda: van a `src/student/`, no a `src/`. |
| `pull access denied` o `repository does not exist` | Revisa que l'`image:` digui exactament `amt132/ampliacio_robotica:2026`. Si està ben escrit, avisa el professorat: la imatge és pública i no t'hauria de demanar res. |
| `docker compose` diu *is not a docker command* | Tens Compose v1 (`docker-compose`, amb guionet). Actualitza Docker Desktop. |
| `no configuration file provided` | No ets a la carpeta on hi ha el `docker-compose.yml`. Fes `cd` fins allà. |
| La descàrrega es talla a mitges | Torna a executar `docker compose up -d`: continua per les capes que ja té, no comença de zero. |
| `no space left on device` | Menys de 12 GB lliures. Allibera disc i, si has provat altres imatges, `docker system prune -a`. |
| `rospack find ...` diu *package not found* però les dreceres existeixen | Problema d'ordre de sourcing. Comprova `echo $ROS_PACKAGE_PATH`: ha de començar per `/home/ubuntu/catkin_ws/src`. |
| "Untrusted application launcher" en prémer una icona | Ja no hauria de passar. Si passa: `docker exec amprobotica-ros cat /var/log/course_desktop_setup.log` |
| VSCodium no s'obre en fer doble clic | Necessita `--no-sandbox`, ja ve posat. Si falla, mira el log de dalt. |
| Stonefish obre finestra però no dibuixa | Qualitat gràfica en `high`. Vegeu la secció de gràfics. |
| L'escriptori es tanca sol | Falta memòria compartida: arrenca amb `docker compose`, no amb `docker run`. |
| No puc escriure a `code/` (Linux) | `sudo chown -R 1000:1000 code` |
| `localhost:6080` no carrega res | Executa `selftest`: la seva secció 6 diu si l'escriptori està servint **dins** del contenidor. Si allà surt tot OK, el problema és del teu navegador o del port (hi ha un altre contenidor ocupant el 6080?); si surt FALLO, `docker compose restart`. |
| `roscore` diu *Unable to contact my own server* | El nom del contenidor no resol. Ho detecta el `selftest` (secció 2). |
| `cm` falla amb errors estranys del compilador | Disc de Docker ple. El `selftest` avisa; des del teu ordinador: `docker system prune -a`. |
| Tot va lentíssim (Mac amb xip Apple) | És emulació. El `selftest` la detecta a la secció 1. Activa Rosetta a Docker Desktop > Settings > General. |

---
