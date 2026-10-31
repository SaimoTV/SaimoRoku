#!/bin/bash
# ====================================================================
# Saimo TV para Roku - Script de Empacotamento Nativo
# Gera o pacote oficial SaimoTV-Roku.zip para publicação e sideloading
# ====================================================================

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Verificando arquivos do canal Roku"
[ -f "manifest" ] || { echo "Erro: manifest não encontrado"; exit 1; }
[ -d "source" ] || { echo "Erro: pasta source não encontrada"; exit 1; }
[ -d "components" ] || { echo "Erro: pasta components não encontrada"; exit 1; }
[ -d "images" ] || { echo "Erro: pasta images não encontrada"; exit 1; }
[ -d "fonts" ] || { echo "Erro: pasta fonts não encontrada"; exit 1; }

VERSION=$(grep -m1 '^major_version' manifest | cut -d'=' -f2).$(grep -m1 '^minor_version' manifest | cut -d'=' -f2).$(grep -m1 '^build_version' manifest | cut -d'=' -f2)
echo "==> Versão do canal Roku: $VERSION"

mkdir -p dist out
ZIP_OUTPUT="dist/SaimoTV-Roku.zip"
rm -f "$ZIP_OUTPUT" "out/SaimoRoku.zip"

echo "==> Montando $ZIP_OUTPUT"
zip -9 -r "$ZIP_OUTPUT" manifest source components images fonts -x "*.DS_Store" "*__MACOSX*"
cp -f "$ZIP_OUTPUT" "out/SaimoRoku.zip"

echo "==> Validando integridade do pacote"
unzip -l "$ZIP_OUTPUT" | head -20

SIZE=$(du -h "$ZIP_OUTPUT" | cut -f1)
SHA=$(shasum -a 256 "$ZIP_OUTPUT" | cut -d' ' -f1)

echo "==> Sucesso: $ZIP_OUTPUT gerado ($SIZE)"
echo "    SHA-256: $SHA"
