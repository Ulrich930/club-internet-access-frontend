# Dockerfile pour le frontend - Production optimisée
FROM node:18-alpine AS builder

WORKDIR /app

# Accepter les build args pour les variables VITE
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

# Copier uniquement les fichiers de dépendances d'abord (cache layer)
COPY package*.json ./

# Installer toutes les dépendances (nécessaires pour le build)
RUN npm ci && \
    npm cache clean --force

# Copier le code source
COPY . .

# Builder l'application avec optimisations
RUN npm run build

# Stage de production avec serveur Nginx optimisé
FROM nginx:alpine

# Installer des outils supplémentaires si nécessaire
RUN apk add --no-cache curl

# Copier les fichiers buildés
COPY --from=builder /app/dist /usr/share/nginx/html

# Créer les répertoires nécessaires avec les bonnes permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d

# Copier la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Modifier la configuration nginx principale
# Commenter la directive user et remplacer/modifier la directive pid
RUN sed -i.bak 's|^user nginx;|# user nginx; commented for Docker USER directive|' /etc/nginx/nginx.conf && \
    sed -i.bak -E 's|^pid\s+/[^;]+;|pid /tmp/nginx.pid;|' /etc/nginx/nginx.conf

# Passer à l'utilisateur nginx
USER nginx

# Exposer le port 80
EXPOSE 80

# Healthcheck (curl fonctionnera car il est exécuté en tant que nginx)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Démarrer Nginx
CMD ["nginx", "-g", "daemon off;"]
