FROM node:10

# Establecer Directorio de trabajo
WORKDIR /usr/src/app

# Copiar contenido de la Aplicación
COPY app/ ./

# Instalar dependencias
RUN npm install

# Exponer puerto 8080
EXPOSE 8080

# Ejecutar Aplicación
CMD ["node", "index.js"]