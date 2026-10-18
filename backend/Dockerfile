# 🐋 Utilisation d'une image de base Node.js LTS épurée et durcie
FROM node:20-alpine

# Configuration de l'environnement de production
ENV NODE_ENV=production

# Définition du répertoire de travail sécurisé
WORKDIR /usr/src/app

# Copie exclusive des manifestes de dépendances
COPY package*.json ./

# Installation stricte des paquets de production (Bypasse les devDependencies)
RUN npm ci --only=production

# 🔄 SÉCURISATION DES COUCHES LOGIQUES COMPLÈTES
COPY server.js ./
COPY config/ ./config/
COPY middleware/ ./middleware/
COPY routes/ ./routes/
COPY controllers/ ./controllers/
COPY public/ ./public/
# 🛡️ SÉCURISATION DES PRIVILÈGES : Attribution des droits au compte non-root 'node'
RUN chown -R node:node /usr/src/app
USER node

# Ouverture du port réseau de communication interne
EXPOSE 5000

# Commande d'exécution immuable du serveur Node.js
CMD ["npm", "start"]
