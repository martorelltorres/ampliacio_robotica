# Instal·lació de l'entorn — Ampliació de Robòtica (UIB)

Guia pas a pas per instal·lar, des de zero, l'entorn de pràctiques de l'assignatura. És un
escriptori Linux amb ROS Noetic que s'obre **al navegador**: no cal instal·lar ROS ni cap
simulador directament al teu ordinador, funciona igual a **Windows, macOS i Linux**.

Temps estimat: 20–40 minuts, la major part esperant la descarga de la imatge (~10 min amb
una connexió normal). Fes-ho **amb temps, no el mateix dia de la primera pràctica**.

## Índex

1. [Què necessites](#1-què-necessites)
2. [Instal·lar Docker](#2-instal·lar-docker) — segons el teu sistema
3. [Obtenir el repositori del curs](#3-obtenir-el-repositori-del-curs)
4. [Arrencar l'entorn](#4-arrencar-lentorn)
5. [Verificar que tot funciona](#5-verificar-que-tot-funciona)
6. [Primeres passes](#6-primeres-passes)
7. [Si alguna cosa falla](#7-si-alguna-cosa-falla)

---

## 1. Què necessites

- Un ordinador amb **Windows 10/11, macOS o Linux**, amb almenys **12 GB d'espai lliure en
  disc** i, si pot ser, 4 GB de RAM disponibles per al contenidor (a més de la que fa
  servir el teu sistema).
- Connexió a internet **només per a la instal·lació**: un cop baixada la imatge, l'entorn
  funciona sense connexió.
- Un navegador (Chrome, Firefox, Edge...). No cal cap programa addicional: ROS, els
  simuladors i l'escriptori van tots dins la imatge.

No cal tenir compte a Docker Hub ni a GitHub per seguir aquesta guia.

---

## 2. Instal·lar Docker

Segueix només la secció del teu sistema operatiu.

### 2.1 Windows

1. **Comprova que tens WSL2.** Obre PowerShell **com a administrador** i executa:
   ```powershell
   wsl --status
   ```
   Si dona error o et diu que cal actualitzar, instal·la'l amb:
   ```powershell
   wsl --install
   ```
   i **reinicia l'ordinador** quan t'ho demani.

2. **Descarrega i instal·la Docker Desktop** des de
   <https://www.docker.com/products/docker-desktop/>. Durant la instal·lació, deixa marcada
   l'opció *"Use WSL 2 instead of Hyper-V"* (és l'opció per defecte).

3. **Obre Docker Desktop** un cop instal·lat i espera que el requadre de baix a l'esquerra
   digui *"Engine running"* (pot trigar un minut el primer cop).

4. **Instal·la Git** si no el tens: <https://git-scm.com/download/win>. Durant la
   instal·lació, deixa totes les opcions per defecte.

5. Obre **PowerShell** (no cal com a administrador a partir d'aquí) i comprova:
   ```powershell
   docker --version
   docker compose version
   git --version
   ```
   Les tres han de respondre amb un número de versió, no un error.

> **Important:** treballa sempre dins una ruta normal del disc (per exemple
> `C:\Users\el_teu_usuari\ampliacio_robotica`), **mai** dins d'OneDrive ni d'una unitat de
> xarxa: la carpeta compartida amb el contenidor falla en aquests casos.

### 2.2 macOS

1. **Comprova quin xip tens**: menú  → *Acerca de este Mac*. Si diu **Apple M1/M2/M3/M4**,
   segueix el pas 3 addicional més avall; si diu **Intel**, no cal.

2. **Descarrega i instal·la Docker Desktop** des de
   <https://www.docker.com/products/docker-desktop/> (tria la versió *Apple Silicon* o
   *Intel chip* segons el pas anterior). Obre'l des d'*Aplicacions* i espera que la balena
   de la barra de menús deixi d'animar-se.

3. **Només si tens xip Apple**: a Docker Desktop, obre *Settings* (l'engranatge) →
   *General*, i activa **"Use Rosetta for x86/amd64 emulation"**. Sense això, l'entorn va
   molt més lent (la imatge és x86_64, no nativa d'Apple Silicon).

4. **Git ja ve instal·lat** a macOS. Comprova-ho obrint *Terminal* (Launchpad → Terminal, o
   `Cmd+Espacio` i escriu "Terminal"):
   ```bash
   git --version
   docker --version
   docker compose version
   ```

### 2.3 Linux

Instal·la **Docker Engine** (no Docker Desktop, encara que també funciona si el prefereixes).
A Ubuntu/Debian:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
```

Després de l'`usermod`, **tanca sessió i torna a entrar** (o reinicia) perquè el canvi de
grup s'apliqui; si no, hauràs de posar `sudo` davant de cada ordre `docker`.

Comprova:

```bash
docker --version
docker compose version   # ha de respondre v2.x
git --version            # si no el tens: sudo apt install git
```

Si `docker compose` (amb espai) dona error però `docker-compose` (amb guionet) funciona,
tens la versió antiga (v1); actualitza Docker Engine.

---

## 3. Obtenir el repositori del curs

Amb Docker i Git ja instal·lats, els passos següents són **idèntics als tres sistemes**,
des de la terminal (PowerShell a Windows, Terminal a macOS/Linux).

Tria una carpeta on treballar (per exemple, la teva carpeta d'usuari) i clona el repositori:

```bash
git clone https://github.com/amt132/ampliacio_robotica.git
cd ampliacio_robotica
```

Això et baixa el `docker-compose.yml`, aquest document, i les carpetes `code/PL0/`,
`code/PL1/` i `code/PL2/` on aniràs desant el teu codi de cada pràctica — buides, a punt
perquè hi creïs el teu paquet catkin quan arribi el moment.

> **Alternativa sense Git:** si no vols instal·lar Git, pots baixar el repositori com a ZIP
> des de la pàgina de GitHub (botó verd *Code* → *Download ZIP*) i descomprimir-lo. El
> resultat és el mateix; només que no podràs actualitzar-lo amb `git pull` si el professorat
> hi publica canvis.

---

## 4. Arrencar l'entorn

Des de la carpeta `ampliacio_robotica` (on hi ha el `docker-compose.yml`):

```bash
docker compose up -d
```

La primera vegada baixa la imatge sencera: **triga uns quants minuts** i gairebé no
imprimeix res mentre ho fa — és normal, no el tanquis. Les properes vegades arrenca en
segons.

Quan acabi, obre el navegador a:

**<http://localhost:6080>**

Dona uns 15 segons a l'escriptori per acabar de muntar-se abans de tocar res.

> ### ⚠ No facis servir `docker run`
>
> És l'error més freqüent en seguir tutorials genèrics d'internet. `docker run` **no munta
> la carpeta compartida `code/`**, així que el teu codi no es desa i desapareix en esborrar
> el contenidor. Fes servir sempre `docker compose up -d` des d'aquesta carpeta.

---

## 5. Verificar que tot funciona

Abans de donar per fet que alguna cosa està trencada, executa l'autotest. És **la mateixa
ordre a Windows, macOS i Linux**:

```bash
docker compose exec ros-dev selftest
```

Ha d'acabar amb:

```
=== RESUMEN ===
  Correctos: 40   Avisos: 1   Fallos: 0

  Entorno correcto. Puedes empezar a trabajar.
```

Si surt algun `[FALLO]`, l'autotest indica la causa i què fer. Consulta la secció
[7. Si alguna cosa falla](#7-si-alguna-cosa-falla) d'aquest document o el README del
repositori. **Guarda sempre la sortida sencera** si has de demanar ajuda al professorat.

---

## 6. Primeres passes

- **On va el teu codi:** dins `code/PL0/`, `code/PL1/` o `code/PL2/`, segons la pràctica.
  És l'única carpeta que sobreviu a `docker compose down` — tot el que hi ha fora es perd
  en tancar el contenidor.
- **Aturar l'entorn** (sense perdre el codi):
  ```bash
  docker compose down
  ```
- **Tornar a arrencar** una altra sessió:
  ```bash
  docker compose up -d
  ```
  i torna a obrir <http://localhost:6080>.
- **Dins l'escriptori** tens un enllaç **`MY_CODE`** que porta directament a la teva
  carpeta compartida.
- **Els atajos de terminal** (`cw`, `cm`, `sw`, `kobuki_sim`, `sparus2`...) i el detall de
  cada pràctica estan documentats al `README.md` del repositori.

---

## 7. Si alguna cosa falla

| Símptoma | Causa i solució |
|---|---|
| `docker: command not found` (o similar) | Docker no s'ha instal·lat correctament, o cal reiniciar la terminal (o l'ordinador) després d'instal·lar-lo. |
| Docker Desktop no arrenca / es queda carregant | Reinicia l'ordinador. A Windows, comprova amb `wsl --status` que WSL2 funciona. |
| `port is already allocated` | Ja tens un contenidor obert. `docker ps` per veure quin, i fes servir aquest. |
| `no space left on device` | Menys de 12 GB lliures. Allibera espai; si has provat altres imatges Docker: `docker system prune -a`. |
| `pull access denied` | Revisa que el `docker-compose.yml` digui exactament `amt132/ampliacio_robotica:2026` a la línia `image:`. Si és correcte, avisa el professorat. |
| La carpeta compartida no es pot escriure (Linux) | `sudo chown -R 1000:1000 code` des del teu ordinador. |
| Tot va molt lent (Mac amb xip Apple) | Comprova que has activat *"Use Rosetta for x86/amd64 emulation"* a Docker Desktop → Settings → General. |
| `localhost:6080` no carrega res | Espera uns 15–20 s més; si segueix igual, `docker compose restart` i torna-ho a provar. |

Per a qualsevol altre problema, executa `selftest` (secció 5) i comparteix la seva sortida
completa amb el professorat — la majoria de vegades ja diu exactament què falla i com
arreglar-ho.
