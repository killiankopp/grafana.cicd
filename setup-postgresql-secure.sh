#!/bin/bash
# Script sécurisé pour créer le secret PostgreSQL
# Ce script NE DOIT PAS être versionné avec des mots de passe !

set -e

echo "=== Configuration sécurisée PostgreSQL pour Grafana ==="

# Variables à personnaliser (PAS de mots de passe ici !)
DB_HOST="postgres.amazone.lan:5432"  # Ex: 192.168.1.100:5432
DB_NAME="grafana"
DB_USER="grafana"
NAMESPACE="grafana"

# Vérification des prérequis
if [ -z "$DB_HOST" ]; then
    echo "❌ Veuillez configurer DB_HOST dans ce script"
    echo "   Exemple: DB_HOST=\"192.168.1.100:5432\""
    exit 1
fi

echo "📊 Configuration:"
echo "  Host: $DB_HOST"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Namespace: $NAMESPACE"
echo

# 1. Mise à jour du values.yaml avec l'host DB
echo "📝 Mise à jour de l'host PostgreSQL dans values.yaml..."
sed -i.bak "s|host: \".*\"|host: \"$DB_HOST\"|" helm/values.yaml
echo "✅ Host mis à jour dans values.yaml"

# 2. Création du namespace
echo "🏗️  Création du namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 3. Création du secret (le mot de passe sera demandé de façon sécurisée)
echo "🔐 Création du secret PostgreSQL..."
echo "⚠️  Le mot de passe ne sera PAS affiché à l'écran"
read -s -p "Mot de passe PostgreSQL pour l'user '$DB_USER': " DB_PASSWORD
echo

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Mot de passe requis"
    exit 1
fi

# Créer le secret dans Kubernetes
kubectl create secret generic grafana-db-secret \
    -n "$NAMESPACE" \
    --from-literal=db-password="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret créé dans Kubernetes (namespace: $NAMESPACE)"

# 4. Vérification
echo "🔍 Vérification du secret..."
kubectl get secret grafana-db-secret -n "$NAMESPACE" >/dev/null && echo "✅ Secret trouvé" || echo "❌ Secret non trouvé"

echo
echo "🚀 Prochaines étapes:"
echo "1. Vérifiez que la base '$DB_NAME' et l'utilisateur '$DB_USER' existent sur PostgreSQL"
echo "2. Commitez les changements (PAS le mot de passe): git add helm/values.yaml && git commit -m 'Update PostgreSQL host'"
echo "3. Poussez: git push"
echo "4. ArgoCD synchronisera automatiquement"
echo
echo "📖 Commandes SQL si la DB n'existe pas:"
echo "   CREATE DATABASE $DB_NAME;"
echo "   CREATE USER $DB_USER WITH PASSWORD 'VOTRE_MOT_DE_PASSE';"
echo "   GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Effacer le mot de passe de la mémoire
unset DB_PASSWORD