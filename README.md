# Franka Panda + qbSoftHand — ROS Noetic (Docker)

Workspace ROS Noetic per il controllo del robot Franka Panda con MoveIt e qbSoftHand come end effector.

> **Nota:** richiede un PC con GPU NVIDIA.

---

## Requisiti

- Linux con driver NVIDIA installati (`nvidia-smi` deve funzionare)
- Docker Engine e Docker Compose installati
- Sessione grafica X11 attiva sul host (`DISPLAY=:0`)
- Utente nei gruppi `audio` e `video`

---

## 1. Clona la repository

```bash
git clone --recurse-submodules -b softhand git@github.com:tonappa/franka.git
cd franka
```

Il flag `--recurse-submodules` scarica automaticamente anche i pacchetti esterni:
- `src/utils/qbdevice-ros` (con i suoi submodule interni)
- `src/utils/qbhand-ros`

Se hai già clonato senza `--recurse-submodules`, recupera i submodule con:

```bash
git submodule update --init --recursive
```

---

## 2. Build dell'immagine Docker

```bash
./run_docker.sh build
```

Installa ROS Noetic con i pacchetti per Franka, MoveIt e i controller.

---

## 3. Avvia il container

```bash
./run_docker.sh run
```

Il container monta il workspace in `/home/ros/franka`, forwarda la GUI via X11 e abilita la GPU NVIDIA.

---

## 4. Build del workspace catkin

Dentro il container:

```bash
catkin build
source devel/setup.bash
```

---

## 5. Ferma il container

```bash
./run_docker.sh down
```

---

## Struttura del progetto

```
franka/
├── docker/
│   ├── Dockerfile          # Immagine ROS Noetic con Franka + MoveIt
│   ├── entrypoint.sh       # Sourcing automatico dell'ambiente ROS
│   └── requirements.txt    # Dipendenze Python (opzionali)
├── src/
│   └── utils/
│       ├── qbdevice-ros/   # Driver qbrobotics (submodule)
│       └── qbhand-ros/     # Pacchetti qbSoftHand (submodule)
├── docker-compose.yaml
└── run_docker.sh
```

---

## Credits

- [Do Won Park](https://github.com/tonappa) — Istituto Italiano di Tecnologia
