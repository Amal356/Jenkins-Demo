# CI/CD avec Jenkins – Compte rendu des Labs 1 et 2

**Étudiante :** Amal Jemli – Master DevOps et Cloud Computing
**Enseignant :** Wahid Hamdi
**Dépôt :** fork de [wahid007/Jenkins-Demo](https://github.com/wahid007/Jenkins-Demo) → [Amal356/Jenkins-Demo](https://github.com/Amal356/Jenkins-Demo)

Application utilisée : une application **Spring Boot** (Java) qui affiche une page HTML sur le port **2222**.

## Sommaire

| Lab | Contenu | Compte rendu |
|---|---|---|
| **Lab 1 – Jenkins CI/CD Pipeline** | Workflow manuel (Maven, Docker, Docker Hub, Kubernetes K3S), puis jobs Jenkins Freestyle et challenge de déploiement automatique sur Kubernetes | [lab1/README.md](lab1/README.md) |
| **Lab 2 – Prise en main et utilisation de Jenkins** | Plugins, configuration de JDK / Maven / Docker, cloud Docker, pipeline défini par un Jenkinsfile | [lab2/README.md](lab2/README.md) |

## Environnement

| Élément | Version / valeur |
|---|---|
| Machine virtuelle | Ubuntu Server 26.04 sous VirtualBox (4 Go RAM, 2 CPU, réseau NAT) |
| Java | OpenJDK 21 |
| Maven | 3.9.12 (VM) / 3.9.16 (installé par Jenkins) |
| Docker | 29.8 |
| Kubernetes | K3S v1.36.5 |
| Jenkins | 2.580.1 (installé en service) |

Accès depuis la machine physique (redirections de ports VirtualBox) :

| Service | Port Windows | Port VM |
|---|---|---|
| SSH | 2222 | 22 |
| Jenkins | 8080 | 8080 |
| Application (conteneur Docker) | 8082 | 2222 |
| Application (Kubernetes NodePort) | 30222 | 30222 |

## Fichiers ajoutés au projet

| Fichier | Rôle |
|---|---|
| `Dockerfile` | image de l'application (`eclipse-temurin:17-jre`) |
| `deployment.yaml`, `service.yaml` | déploiement Kubernetes (2 réplicas, NodePort 30222) |
| `freestyle/script.sh`, `freestyle/Test.java` | script récupéré depuis GitHub par le job freestyle |
| `Jenkinsfile` | pipeline du Lab 2 |
| `lab1/`, `lab2/` | comptes rendus et captures d'écran |
