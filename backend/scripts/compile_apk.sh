#!/bin/bash
set -e

# Récupération des paramètres passés par Node.js
WEB_FINGERPRINT=$1
MANIFEST_JSON=$2
OUTPUT_DIR=$3
FLUTTER_PROJECT_PATH="/d/dev/dabafoodstall/frontend"

echo "⚙️ [COMPILER Bash] Écriture de la configuration d'usine personnalisée..."

cd "$FLUTTER_PROJECT_PATH"
mkdir -p assets/config

# Injection atomique du fichier complet calculé par le serveur
echo "$MANIFEST_JSON" > assets/config/identity.json

echo "📝 [COMPILER Bash] identity.json scellé avec le catalogue et le bloc RH."

# Nettoyage et compilation du projet mobile
flutter clean
flutter pub get
echo "🚀 [COMPILER Bash] Construction du binaire Android Release..."
flutter build apk --release

# Sécurisation et déplacement du livrable
TARGET_APK_NAME="genzo_pos_${WEB_FINGERPRINT}.apk"
mkdir -p "$OUTPUT_DIR"
cp build/app/outputs/flutter-apk/app-release.apk "${OUTPUT_DIR}/${TARGET_APK_NAME}"

echo "✅ [COMPILER Bash] Précompilation SaaS exécutée avec succès."
