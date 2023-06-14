#!/bin/bash
set -e

cd functions
npm run lint:fix
npm run build
cd ..
flutter build web --web-renderer html --release
firebase deploy