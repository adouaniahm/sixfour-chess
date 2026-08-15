#!/bin/sh

# Script exécuté avant chaque build Xcode Cloud
# Ce script prépare l'environnement de build

set -e  # Arrête en cas d'erreur

echo "🚀 FreeChess - Pre-build script"
echo "================================"

# Affiche les informations de l'environnement
echo "📋 Informations de build:"
echo "- Xcode version: $(xcodebuild -version)"
echo "- Swift version: $(swift --version)"
echo "- macOS version: $(sw_vers -productVersion)"
echo ""

# Affiche les variables d'environnement Xcode Cloud
echo "🔧 Variables d'environnement:"
echo "- CI_WORKSPACE: ${CI_WORKSPACE:-non défini}"
echo "- CI_XCODEBUILD_ACTION: ${CI_XCODEBUILD_ACTION:-non défini}"
echo "- CI_WORKFLOW: ${CI_WORKFLOW:-non défini}"
echo "- CI_BRANCH: ${CI_BRANCH:-non défini}"
echo "- CI_TAG: ${CI_TAG:-non défini}"
echo ""

# Vérifie la structure du projet
echo "📁 Vérification de la structure du projet..."
if [ -d "${CI_WORKSPACE}/FreeChessApp" ]; then
    echo "✅ Répertoire FreeChessApp trouvé"
else
    echo "❌ Répertoire FreeChessApp non trouvé"
    exit 1
fi

# Vérifie les fichiers essentiels
if [ -f "${CI_WORKSPACE}/FreeChessApp/FreeChessApp.xcodeproj/project.pbxproj" ]; then
    echo "✅ Projet Xcode trouvé"
else
    echo "❌ Projet Xcode non trouvé"
    exit 1
fi

# Nettoie les fichiers temporaires si nécessaire
echo "🧹 Nettoyage des fichiers temporaires..."
find "${CI_WORKSPACE}" -name ".DS_Store" -delete 2>/dev/null || true
echo "✅ Nettoyage terminé"
echo ""

# Résolution des dépendances Swift Package Manager
echo "📦 Résolution des dépendances Swift Package Manager..."
if [ -f "${CI_WORKSPACE}/Package.swift" ]; then
    echo "⚠️  Package.swift détecté à la racine (peut causer des conflits)"
    echo "   Le projet utilise le Package.swift du workspace Xcode"
fi
echo "✅ Prêt pour la compilation"
echo ""

echo "✨ Pre-build script terminé avec succès!"
echo "================================"
