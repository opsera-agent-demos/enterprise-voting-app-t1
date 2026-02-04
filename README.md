# Example Voting App

[![Deployment Landscape](https://img.shields.io/badge/📊_Deployment-Landscape-blue?style=for-the-badge)](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/deployment-landscape-voting01.yaml)
[![CI/CD DEV](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/ci-build-push-voting01-dev.yaml/badge.svg)](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/ci-build-push-voting01-dev.yaml)

---

## 🚀 Deployment Dashboard

<!-- DEPLOYMENT-STATUS:START - Auto-updated by landscape workflow -->
| Environment | App | Last Deploy | Owner | Recent Deployments |
|-------------|-----|-------------|-------|-------------------|
| 🔧 **DEV** | [Vote](https://vote-voting01-dev.agent.opsera.dev) / [Result](https://result-voting01-dev.agent.opsera.dev) | 1 min ago | Sai Manasa G | • `7f1da79-2026` (1 min ago)<br>• `0961c14-2026` (24 mins ago)<br>• `5289e44-2026` (31 mins ago)<br>• `c852b04-2026` (41 mins ago)<br>• `ea6c479-2026` (52 mins ago) |
| 🧪 **QA** | [Vote](https://vote-voting01-qa.agent.opsera.dev) / [Result](https://result-voting01-qa.agent.opsera.dev) | 20 mins ago | srinivas-source | • `0961c14-2026` (20 mins ago)<br>• `bebfee0-2026` (16h 12m ago)<br>• `364ac1a-2026` (16h 29m ago)<br>• `1cb6f68-2026` (16h 43m ago)<br>• `b80045f-2026` (17 hrs ago) |
| 🎭 **Staging** | [Vote](https://vote-voting01-staging.agent.opsera.dev) / [Result](https://result-voting01-staging.agent.opsera.dev) | 4 mins ago | srinivas-source | • `0961c14-2026` (4 mins ago)<br>• `bebfee0-2026` (16h 12m ago)<br>• `364ac1a-2026` (16h 13m ago)<br>• `1cb6f68-2026` (16h 31m ago)<br>• `00178af-2026` (17h 5m ago) |

> 📅 _Last updated: 2026-02-04 00:31 UTC_ | [🔄 Refresh](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/deployment-landscape-voting01.yaml)
<!-- DEPLOYMENT-STATUS:END -->

### Quick Actions

| Action | Link |
|--------|------|
| 📊 **View Full Landscape Report** | [▶️ Open Dashboard](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/deployment-landscape-voting01.yaml) |
| 🔧 Deploy to DEV | [▶️ Run](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/ci-build-push-voting01-dev.yaml) |
| 🧪 Deploy to QA | [▶️ Run](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/ci-build-push-voting01-qa.yaml) |
| 🎭 Deploy to Staging (Preview) | [▶️ Run](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/ci-build-push-voting01-staging.yaml) |
| 🚀 **Promote Staging to Active** | [▶️ Run](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/promote-staging-rollout-voting01.yaml) |
| ⬆️ Promote Environment (DEV→QA→Staging) | [▶️ Run](https://github.com/opsera-agentic/enterprise-voting-demo-only/actions/workflows/promote-voting01.yaml) |

---

A simple distributed application running across multiple Docker containers.

## Getting started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```

## Run the app in Kubernetes

The folder k8s-specifications contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it.)

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc), and how to
deal with them in Docker at a basic level.
