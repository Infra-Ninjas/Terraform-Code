# ---- Step 1: Build the React App ----
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm install --legacy-peer-deps --no-fund --no-audit

# Copy the rest of the app files
COPY . .

# Build the React app
RUN npm run build

# ---- Step 2: Serve with Nginx ----
FROM nginx:alpine

# Remove default Nginx static content
RUN rm -rf /usr/share/nginx/html/*

# Copy built React app from the previous stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom Nginx config (for React routing support)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
    
#LOCAL BUILD
# docker build -t my-app .
# docker tag my-app rupeshcapstoneacr.azurecr.io/my-app:latest
# az acr login --name rupeshcapstoneacr
# docker push rupeshcapstoneacr.azurecr.io/my-app:latest
# az acr repository list --name rupeshcapstoneacr --output table

#AZURE CLI COMMANDS
# sudo apt-get update
# sudo apt-get install -y ca-certificates curl lsb-release gnupg docker.io
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# az --version
# az login --identity
# sudo systemctl enable docker
# sudo systemctl start docker
# docker --version
# sudo usermod -aG docker $USER
## Now restart the vm and ssh again into the vm
# docker --version
# sudo systemctl status docker
# newgrp docker
# az acr login --name rupeshcapstoneacr
# docker pull rupeshcapstoneacr.azurecr.io/my-app:latest
# docker images
# docker run -d -p 8000:80 rupeshcapstoneacr.azurecr.io/my-app:latest
# docker ps
# curl http://localhost:8000
# http://<PUBLIC_IP>:8000