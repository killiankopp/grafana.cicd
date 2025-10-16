# Grafana Deployment avec GitOps (ArgoCD + Helm)

## Architecture
- **Cluster**: k3d local
- **GitOps**: ArgoCD 
- **Package Manager**: Helm Chart
- **Ingress**: NGINX Ingress Controller avec TLS (cert-manager)
- **Storage**: PVC avec StorageClass par défaut
- **Secrets**: Générés automatiquement, aucun secret en dur

## Structure du projet
```
├── README.md
├── argocd/
│   └── app.yaml                 # Application ArgoCD
└── helm/
    ├── Chart.yaml
    ├── values.yaml              # Variables de configuration
    └── templates/
        ├── deployment.yaml      # Deployment Grafana
        ├── service.yaml         # Service ClusterIP
        ├── ingress.yaml         # Ingress NGINX avec TLS
        └── secret.yaml          # Secret auto-généré admin password
```

## Prérequis
- Cluster k3d déployé et fonctionnel
- ArgoCD installé et configuré
- NGINX Ingress Controller installé
- cert-manager installé avec ClusterIssuer `local-amazone`
- Résolution DNS pour `grafana.amazone.lan` vers votre cluster

## Déploiement

### 1. Configuration PostgreSQL (OBLIGATOIRE)

**Créer le secret avec le mot de passe DB :**
```bash
# Créer le namespace
kubectl create namespace grafana

# Créer le secret (remplacez YOUR_PASSWORD)
kubectl create secret generic grafana-db-secret \
    -n grafana \
    --from-literal=db-password='YOUR_PASSWORD'
```

**Configurer l'host PostgreSQL dans `helm/values.yaml` :**
```yaml
database:
  host: "192.168.1.100:5432"  # Remplacez par votre serveur PostgreSQL
```

**Créer la base de données sur PostgreSQL :**
```sql
CREATE DATABASE grafana;
CREATE USER grafana WITH PASSWORD 'YOUR_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
```

### 2. Déployer l'application ArgoCD
```bash
kubectl apply -f argocd/app.yaml
```

### 3. Vérifier le déploiement
```bash
# Status ArgoCD
kubectl get application grafana -n argocd

# Pods Grafana
kubectl get pods -n grafana

# Secret admin
kubectl get secret grafana-admin-secret -n grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

### 4. Accès à Grafana

- **URL**: <https://grafana.amazone.lan>
- **Username**: admin
- **Password**: Récupérer via la commande ci-dessus

## Configuration

### Variables principales (values.yaml)
- `image.tag`: Version de Grafana
- `ingress.hostname`: Nom de domaine
- `persistence.size`: Taille du stockage
- `resources`: Limites CPU/mémoire

### Personnalisation
Modifier `helm/values.yaml` et pousser sur git. ArgoCD synchronisera automatiquement.

## Opérations

### Mise à jour Grafana
1. Modifier `image.tag` dans `values.yaml`
2. Commit + push
3. ArgoCD sync automatique (ou manuel)

### Scaling
Modifier `replicaCount` dans `values.yaml` (déconseillé avec PVC)

### Backup
Le stockage persistant est sur PVC. Implémenter une stratégie de backup selon vos besoins.

## Limitations

- **Database PostgreSQL**: Nécessite un serveur PostgreSQL externe accessible depuis le cluster
- **Scale horizontal**: Possible avec PostgreSQL (contrairement à SQLite)  
- **Monitoring**: Pas de monitoring intégré (Prometheus, logs)
- **Secrets**: Le mot de passe PostgreSQL doit être créé manuellement dans Kubernetes

## Sécurité
- TLS activé via cert-manager
- Admin password auto-généré
- Pas de secrets en dur dans le code
- SecurityContext configuré (non-root)

## Troubleshooting

### Pods en erreur
```bash
kubectl describe pod -n grafana -l app.kubernetes.io/name=grafana
kubectl logs -n grafana -l app.kubernetes.io/name=grafana
```

### Ingress/DNS
```bash
kubectl get ingress -n grafana
kubectl describe ingress grafana -n grafana
```

### ArgoCD sync
```bash
kubectl get application grafana -n argocd -o yaml
```