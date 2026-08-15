#!/bin/sh

# Script exécuté après chaque build Xcode Cloud
# Ce script effectue des tâches post-build

set -e  # Arrête en cas d'erreur

echo "🎉 FreeChess - Post-build script"
echo "================================"

# Affiche le statut du build
if [ "${CI_XCODEBUILD_EXIT_CODE}" = "0" ]; then
    echo "✅ Build réussi!"
else
    echo "❌ Build échoué avec le code: ${CI_XCODEBUILD_EXIT_CODE}"
fi
echo ""

# Affiche les informations de l'artefact
echo "📦 Informations sur l'artefact:"
if [ -n "${CI_ARCHIVE_PATH}" ]; then
    echo "- Archive path: ${CI_ARCHIVE_PATH}"

    # Affiche la taille de l'archive
    if [ -f "${CI_ARCHIVE_PATH}" ]; then
        ARCHIVE_SIZE=$(du -sh "${CI_ARCHIVE_PATH}" | cut -f1)
        echo "- Taille de l'archive: ${ARCHIVE_SIZE}"
    fi
fi
echo ""

# Génère un rapport de build
echo "📊 Génération du rapport de build..."
BUILD_REPORT="${CI_DERIVED_DATA_PATH}/build_report.txt"
{
    echo "FreeChess Build Report"
    echo "======================"
    echo ""
    echo "Date: $(date)"
    echo "Workflow: ${CI_WORKFLOW}"
    echo "Branch: ${CI_BRANCH:-N/A}"
    echo "Tag: ${CI_TAG:-N/A}"
    echo "Commit: ${CI_COMMIT:-N/A}"
    echo "Action: ${CI_XCODEBUILD_ACTION}"
    echo "Exit Code: ${CI_XCODEBUILD_EXIT_CODE}"
    echo ""
    echo "Environment:"
    echo "- Xcode: $(xcodebuild -version | head -n1)"
    echo "- Swift: $(swift --version | head -n1)"
    echo "- macOS: $(sw_vers -productVersion)"
} > "${BUILD_REPORT}"

echo "✅ Rapport sauvegardé: ${BUILD_REPORT}"
echo ""

# Collecte les statistiques du projet
echo "📈 Statistiques du projet:"
if [ -d "${CI_WORKSPACE}/FreeChessApp/FreeChessApp" ]; then
    SWIFT_FILES=$(find "${CI_WORKSPACE}/FreeChessApp/FreeChessApp" -name "*.swift" | wc -l)
    SWIFT_LINES=$(find "${CI_WORKSPACE}/FreeChessApp/FreeChessApp" -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
    echo "- Fichiers Swift: ${SWIFT_FILES}"
    echo "- Lignes de code: ${SWIFT_LINES}"
fi
echo ""

echo "✨ Post-build script terminé!"
echo "================================"
