# Lab 1 – Jenkins CI/CD Pipeline

[← Retour au sommaire](../README.md)

Objectif : déployer une application Spring Boot dans Kubernetes, d'abord **manuellement** (partie I), puis en l'**automatisant avec Jenkins** (partie II).

Projet de départ : fork de `https://github.com/wahid007/Jenkins-Demo.git` sur mon compte GitHub, cloné dans la VM :

```bash
git clone git@github.com:Amal356/Jenkins-Demo.git
cd Jenkins-Demo
sudo apt install -y maven
```

![Fork du projet](screenshots/00-fork.png)

---

# Partie I – Workflow manuel (sans Jenkins)

## Étape 1 – Dockerfile

Le Dockerfile d'origine utilisait l'image `openjdk:17-jdk-slim`, obsolète. Il est remplacé par celui de l'énoncé, basé sur **eclipse-temurin:17-jre**, avec le nom réel du JAR produit par Maven :

```dockerfile
# java jdk 17
FROM eclipse-temurin:17-jre

# Set port number
EXPOSE 2222

# Set the working directory in the container
WORKDIR /app

# Copy the packaged JAR file into the container
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar app.jar

# Specify the command to run on container startup
CMD ["java", "-jar", "app.jar"]
```

- `FROM` : image de base contenant uniquement l'environnement d'exécution Java 17 (JRE), plus légère qu'un JDK ;
- `EXPOSE 2222` : l'application écoute sur le port 2222 (`server.port=2222` dans `application.properties`) ;
- `COPY` : le JAR construit par Maven est copié dans l'image ;
- `CMD` : commande lancée au démarrage du conteneur.

![Dockerfile](screenshots/01-dockerfile.png)

## Étape 2 – Build Maven et image Docker

```bash
mvn clean install
ls -lh target/*.jar
```

Maven télécharge les dépendances, compile, exécute le test, puis produit `target/devOpsDemo-0.0.1-SNAPSHOT.jar` (24 Mo). Le projet (Spring Boot 2.1.5, Java 8) se compile sans problème avec Java 21.

![Build Maven](screenshots/02-mvn-build.png)

```bash
docker build -t devops-demo:1.0.0 .
docker images devops-demo
```

![Build de l'image](screenshots/03-docker-build.png)

## Étape 3 – Publication sur Docker Hub

Mon compte Docker Hub est lié à Gmail (pas de mot de passe Docker) : la connexion se fait avec un **Personal Access Token** (Read & Write), plus sûr qu'un mot de passe.

```bash
docker login -u amal878
docker tag devops-demo:1.0.0 amal878/devops-demo:1.0.0
docker push amal878/devops-demo:1.0.0
```

![Login, tag et push](screenshots/04-docker-push.png)

![Image sur Docker Hub](screenshots/05-dockerhub.png)

Lancement d'un conteneur à partir de l'image publiée :

```bash
docker run --detach --name devops-demo --publish 2222:2222 amal878/devops-demo:1.0.0
docker ps
curl http://localhost:2222
```

![docker run et curl](screenshots/06-docker-run.png)

Depuis Windows, le port 2222 est déjà utilisé par la redirection SSH. Une redirection VirtualBox **8082 → 2222** (et `sudo ufw allow 2222/tcp`) permet d'ouvrir l'application sur `http://localhost:8082` :

![Application dans le navigateur](screenshots/07-app-navigateur.png)

## Étape 4 – Déploiement sur Kubernetes (K3S)

### Installation de K3S

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik
sudo ufw allow 6443/tcp
sudo ufw allow from 10.42.0.0/16
sudo ufw allow from 10.43.0.0/16
sudo ufw allow 30222/tcp
kubectl get nodes
kubectl get pods -A
```

- `--write-kubeconfig-mode 644` : le fichier de configuration est lisible par `kubectl` (et plus tard par Jenkins) ;
- `--disable traefik` : composant inutile ici, désactivé pour économiser la mémoire de la VM ;
- règles UFW : API Kubernetes (6443), réseaux internes des pods (10.42.0.0/16) et des services (10.43.0.0/16), port NodePort de l'application.

![Installation de K3S](screenshots/08-k3s-install.png)

### Manifests

L'application écoute sur **2222** : les ports de l'énoncé (8080) sont adaptés, et l'image utilisée est celle publiée sur Docker Hub.

`deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
        - name: spring-app-container
          image: amal878/devops-demo:1.0.0
          ports:
            - containerPort: 2222
```

`service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
spec:
  selector:
    app: spring-app
  ports:
    - protocol: TCP
      port: 2222
      targetPort: 2222
      nodePort: 30222
  type: NodePort
```

- `replicas: 2` : deux pods de l'application tournent en parallèle ;
- le `selector` `app: spring-app` relie le Service aux pods ;
- `NodePort 30222` : l'application est exposée sur le port 30222 de la VM.

![Manifests](screenshots/09-yaml.png)

### Déploiement

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/spring-app-deployment
kubectl get pods
kubectl apply -f service.yaml
kubectl get svc
curl http://localhost:30222
```

Les deux pods sont `Running` et le service `spring-app-service` est exposé en `2222:30222/TCP`.

![Déploiement Kubernetes](screenshots/10-kubectl-deploy.png)

Avec la redirection VirtualBox **30222 → 30222**, l'application servie par Kubernetes s'ouvre sur `http://localhost:30222` :

![Application servie par Kubernetes](screenshots/11-app-k8s.png)

---

# Partie II – Jenkins Freestyle

## Étape 1 – Job `freestyle_demo`

Nouveau Item → **Construire un projet free-style** → étape de build « Exécuter un script shell » :

```bash
echo 'Bonjour'
ls -l
echo 'Bonjour DevOps' > test.txt
ls -l
```

![Console du job](screenshots/12-freestyle-console.png)

Le fichier `test.txt` est bien créé dans le workspace du job :

```bash
sudo ls -l /var/lib/jenkins/workspace/freestyle_demo
sudo cat /var/lib/jenkins/workspace/freestyle_demo/test.txt
```

![Workspace du job](screenshots/13-freestyle-workspace.png)

## Étape 2 – Exécuter un fichier Java

Création de `Test.java` dans le workspace (en tant qu'utilisateur `jenkins`, propriétaire du workspace) :

```bash
sudo -u jenkins tee /var/lib/jenkins/workspace/freestyle_demo/Test.java > /dev/null << 'EOF'
public class Test {
    public static void main(String[] args) {
        System.out.println("Hi Master DevOps");
    }
}
EOF
```

![Test.java](screenshots/14-test-java.png)

Ajout de `java Test.java` au script du job : depuis Java 11, cette commande compile et exécute le fichier en une seule étape.

![Hi Master DevOps](screenshots/15-freestyle-java.png)

## Étape 3 – Script récupéré depuis GitHub

Le script est placé dans le dépôt GitHub (`freestyle/script.sh` et `freestyle/Test.java`) :

```bash
#!/bin/bash
echo 'Bonjour (script récupéré depuis GitHub)'
ls -l
echo 'Bonjour DevOps' > test.txt
ls -l
java freestyle/Test.java
```

![Script poussé sur GitHub](screenshots/16-script-github.png)

Configuration du job : **Gestion de code source → Git**, dépôt `https://github.com/Amal356/Jenkins-Demo.git`, branche `*/main`, et une seule étape de build : `bash freestyle/script.sh`.

![Configuration Git](screenshots/17-freestyle-github-config.png)

![Étape de build](screenshots/17b-freestyle-build-step.png)

Jenkins clone le dépôt puis exécute le script :

![Console : clonage et exécution du script](screenshots/18-freestyle-github-console.png)

## Étape 4 – Déclenchement automatique et conservation des builds

| Option | Configuration |
|---|---|
| Garder uniquement les 2 derniers builds | Général → **Supprimer les anciens builds** → Log Rotation, maximum **2** |
| Déclenchement toutes les 5 minutes | Triggers → **Construire périodiquement** → `H/5 * * * *` |
| Supprimer le workspace avant le build | Environment → **Delete workspace before build starts** |

![Supprimer les anciens builds](screenshots/19-config-discard.png)

![Construire périodiquement](screenshots/20-config-trigger.png)

![Delete workspace](screenshots/21-config-delete-workspace.png)

Résultat : le build #4 s'est lancé seul à 21:08 UTC (heure annoncée par Jenkins) et seuls les 2 derniers builds sont conservés (#3 et #4, les #1 et #2 ont été supprimés automatiquement).

![Builds automatiques](screenshots/22-builds-auto.png)

![Lancé par une alarme périodique](screenshots/23-lance-par-timer.png)

![Console du build automatique](screenshots/24-console-timer.png)

## Étape 5 – Challenge : du build au déploiement Kubernetes

Job freestyle `freestyle_deploy_k8s` qui automatise toute la chaîne : **Maven → image Docker → Docker Hub → Kubernetes → test**.

### Sécurité : token Docker Hub dans les Credentials Jenkins

Le token n'est jamais écrit dans le script : il est stocké dans **Administrer Jenkins → Credentials** (type « Nom d'utilisateur et mot de passe », ID `dockerhub-credentials`).

![Credentials](screenshots/25-credentials.png)

Pour vérifier que le déploiement est réel, le titre de la page est modifié et poussé sur GitHub :

![Nouveau titre](screenshots/25b-challenge-titre.png)

### Configuration du job

- **Environment → Use secret text(s) or file(s)** : liaison *Username and password (separated)*, variables `DOCKER_USER` et `DOCKER_PASS` ;
- **Gestion de code source** : dépôt GitHub, branche `*/main`.

![Variables secrètes](screenshots/26-challenge-config-env.png)

![Dépôt Git](screenshots/26b-challenge-config-git.png)

### Script du job

```bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
IMAGE=amal878/devops-demo
TAG=$BUILD_NUMBER

echo "===== 1. Build Maven ====="
mvn -B clean package

echo "===== 2. Build image Docker ====="
docker build -t $IMAGE:$TAG .

echo "===== 3. Push sur Docker Hub ====="
echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
docker push $IMAGE:$TAG
docker logout

echo "===== 4. Deploiement Kubernetes ====="
sed "s|image: .*|image: $IMAGE:$TAG|" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl rollout status deployment/spring-app-deployment --timeout=180s
kubectl get pods
kubectl get svc spring-app-service

echo "===== 5. Test de l'application ====="
for i in $(seq 1 12); do
  if curl -s http://localhost:30222 | grep "<h1>"; then
    echo "Application deployee et accessible"
    exit 0
  fi
  echo "Application pas encore prete, nouvel essai dans 5 s..."
  sleep 5
done
echo "Application injoignable apres 60 s"
exit 1
```

- `set -e` : le job s'arrête à la première erreur ;
- `TAG=$BUILD_NUMBER` : chaque build produit une image avec un tag unique (`:3`, `:4`…) ;
- `--password-stdin` : le token est transmis sans apparaître dans la ligne de commande ;
- `sed … | kubectl apply -f -` : déploie la nouvelle image sans modifier le fichier du dépôt ;
- `rollout status` : attend que les nouveaux pods soient prêts ;
- étape 5 : test avec plusieurs essais, car Spring Boot met une vingtaine de secondes à démarrer dans un pod.

![Script du job](screenshots/27-challenge-script.png)

### Exécution

![Début : clonage et build Maven](screenshots/28-challenge-console.png)

Le token est masqué dans les logs (`echo ****`) :

![Push sur Docker Hub](screenshots/28a-challenge-push.png)

![Fin : déploiement et test](screenshots/28b-challenge-console-fin.png)

La nouvelle version est servie par Kubernetes :

![Nouveau titre sur localhost:30222](screenshots/29-challenge-resultat.png)

### Problèmes rencontrés

1. **Build annulé pendant le test** : le test Spring démarre sans rien afficher pendant plusieurs secondes ; annulé à tort, le build affichait `Tests run: 0` et `There are test failures`. Relancé sans interruption, le test passe (`Tests run: 1, Failures: 0`).
2. **Test final trop rapide** : `curl` interrogeait le service alors que les nouveaux pods démarraient encore. Remplacé par une boucle de 12 essais espacés de 5 secondes.

[← Retour au sommaire](../README.md)
