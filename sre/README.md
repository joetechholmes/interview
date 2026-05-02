# Site Reliability Engineering Interview Guidelines

Welcome to the Site Reliability Engineer take-home coding challenge! 

This project is designed to evaluate your skills in `productionizing applications`, `managing container orchestration`, and ensuring the `reliability` and `observability` of services in a `Kubernetes production environment`.

## Overview:

Your goal is to create a containerized deployment strategy using Docker and deploy the application(s) on Kubernetes (K8s) with Helm charts.

Make sure you to include a minimal CI/CD pipeline to help you out.

The application to be containerized is bundled in this repository:
- [Backend Service](../backend/README.md) - Backend Application (BE)

This assignment will give us insight into your technical expertise, problem-solving skills, and ability to work with modern infrastructure tools.

#### Fork the repository and clone it locally
- https://github.com/Tekmetric/interview.git

#### Import project into IDE
- Project root is located in `sre` folder

#### After finishing the goals listed below create a PR

- if you've forked the repository, create a PR from your fork to `Tekmetric/interview` repository
# Goals
1. Create a Dockerfile to containerize the application.
2. Create a minimal CI/CD pipeline to demonstrate building and pushing Docker images to a container registry (e.g., Docker Hub, AWS ECR, etc.).
3. Develop a Helm chart to deploy the application on a K8s or K3s cluster.
   1. Make sure that whatever you implement in the Helm chart is `as close as possible to production-ready`.
4. Add relevant observability
5. Provide clear instructions on how to build and deploy the application, including any prerequisites.

## Local Kubernetes bootstrap
A helper script is available in `sre/bootstrap-minikube.sh` to:
- detect and install `minikube` for Linux/macOS
- start a local minikube cluster
- install Istio into namespace `istio`
- install cert-manager into namespace `cert-manager`
- install External Secrets Operator into namespace `eso`

Run it from the `sre` folder:

```bash
./bootstrap-minikube.sh
```

# Considerations
This is an open-ended exercise for you to showcase what you know!

### Submitting your coding exercise
Once you have finished the coding exercise please create a PR into Tekmetric/interview

### Excited to see what you build! 🚀

For the interview, make sure you have the following ready:
- An IDE with your submission code
- A running K8s or K3s cluster (local or cloud-based) to demonstrate your Helm chart deployment
- Make sure you can explain your design choices and answer any questions related to the exercise.
- You will have only 10 minutes to showcase your submission during the interview, so please be concise and focus on the key aspects of your implementation.
