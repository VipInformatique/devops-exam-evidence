#!/bin/bash

# setup_env.sh – DevOps environment for K3s v1.32.5

set -e

echo "📦 Creating Python virtual environment..."
python3 -m venv venv

echo "✅ Activating environment..."
source venv/bin/activate

echo "⬆️ Upgrading pip, setuptools and wheel..."
pip install --upgrade pip setuptools wheel

echo "📥 Installing Ansible 7.7.0 + ansible-core 2.14.7 + Jinja2 3.0.3 + Kubernetes SDK 33.1.0..."
pip install \
  ansible==7.7.0 \
  ansible-core==2.14.7 \
  jinja2==3.0.3 \
  kubernetes==33.1.0

echo "📥 Installing Ansible collection for Kubernetes..."
ansible-galaxy collection install kubernetes.core

echo "🧪 Checking installed versions:"
ansible --version

echo "✅ Environment ready! Activate it using:"
echo "source venv/bin/activate"
