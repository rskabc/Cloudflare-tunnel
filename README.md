# Cloudflare Tunnel (Docker) → Nginx Proxy Manager

Deploy a Cloudflare Tunnel connector with Docker Compose and route public hostnames to an existing Nginx Proxy Manager (NPM) instance.

> This repository does not contain a real tunnel token. Keep your token in the local `.env` file and never commit it.

## Architecture

```text
Browser
  │ HTTPS
  ▼
Cloudflare edge
  │ Cloudflare Tunnel (outbound connection)
  ▼
cloudflared container
  │ shared Docker network
  ▼
Nginx Proxy Manager :80
  │ hostname-based proxy rules
  ▼
Your local apps
```

## Requirements

- Docker Engine and Docker Compose plugin on the server.
- A Cloudflare account and a tunnel created in the Cloudflare Zero Trust dashboard.
- Nginx Proxy Manager already running in Docker.
- The existing Docker network used by NPM, identified before deployment.

## 1. Get the tunnel token

In Cloudflare Zero Trust, open **Networks → Tunnels**, select your tunnel, and open the connector/install instructions. Copy the tunnel token from the command Cloudflare provides. Treat it as a password.

## 2. Clone and configure

Choose the deployment directory (example: `/opt/cloudflare-tunnel`):

```bash
sudo mkdir -p /opt/cloudflare-tunnel
sudo chown "$USER":"$USER" /opt/cloudflare-tunnel
git clone https://github.com/rskabc/Cloudflare-tunnel.git /opt/cloudflare-tunnel
cd /opt/cloudflare-tunnel
cp .env.example .env
nano .env
```

Set `TUNNEL_TOKEN` to the token from Cloudflare. Do not put the token in Git, shell history, screenshots, or chat.

## 3. Find NPM's Docker network

List containers and networks:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
docker network ls
```

Inspect the actual NPM container name (replace the example):

```bash
docker inspect <npm-container-name> --format '{{json .NetworkSettings.Networks}}'
```

Copy the exact network name from the output into `NPM_DOCKER_NETWORK` in `.env`. The default `npm_network` is only an example; it may not exist on your server. The cloudflared container must join a network that can reach NPM.

## 4. Start the connector

```bash
chmod +x deploy.sh
./deploy.sh
```

Or run Compose directly after confirming the network exists:

```bash
docker compose up -d
docker compose logs -f cloudflared
```

Check status:

```bash
docker compose ps
```

The tunnel should show as healthy/connected in the Cloudflare dashboard. The Compose healthcheck only checks that the binary can report its version; Cloudflare's dashboard and container logs are the source of truth for tunnel connectivity.

## 5. Configure the public hostname in Cloudflare

In the tunnel's published application routes (sometimes labelled **Public Hostnames**):

- **Subdomain:** the hostname you want, e.g. `app`
- **Domain:** your domain managed by Cloudflare
- **Service type:** HTTP
- **URL:** `http://<npm-container-name>:80`

Use the actual NPM container name or Docker DNS alias reachable on the shared network. Do not use `localhost:80` from inside the cloudflared container; localhost points to cloudflared itself.

## 6. Configure Nginx Proxy Manager

In NPM, create a Proxy Host for the same hostname:

- **Domain Names:** e.g. `app.example.com`
- **Scheme:** `http`
- **Forward Hostname / IP:** the app's Docker service name or reachable LAN IP
- **Forward Port:** the app's internal port
- Enable Websockets Support only if the app requires it.

Use the same hostname in Cloudflare and NPM. Cloudflare terminates public HTTPS at its edge and sends traffic through the tunnel to NPM over the configured internal HTTP connection. If you need end-to-end encryption from cloudflared to NPM, configure an HTTPS origin and validate its certificate appropriately.

## 7. Useful commands

```bash
# Follow logs
docker compose logs -f cloudflared

# Restart
docker compose restart cloudflared

# Update image
docker compose pull
docker compose up -d

# Stop and remove container (keeps .env and files)
docker compose down
```

## Security notes

- Never commit `.env`; it is ignored by Git.
- Keep the tunnel token private. Rotate it in Cloudflare if it is exposed.
- Do not publish the NPM administration interface (normally port 81) through this route. Point the tunnel at NPM's proxy listener on port 80.
- A tunnel avoids inbound port forwarding but does not replace application authentication, access policies, patching, or backups.
- Keep this repository private if you prefer to keep infrastructure details out of public view.

## Troubleshooting

- **Tunnel cannot connect:** check `docker compose logs -f cloudflared`, outbound internet access, token, and tunnel status in Cloudflare.
- **Network not found:** set `NPM_DOCKER_NETWORK` to the exact existing network used by NPM.
- **502 Bad Gateway:** confirm cloudflared can reach NPM on the shared Docker network and that the service URL points to the NPM container on port 80.
- **Cloudflare works but app fails:** verify the hostname exists in NPM and that NPM can reach the app's configured upstream.
