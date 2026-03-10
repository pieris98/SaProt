# Sub-project Dockerfile for SaProt (Monorepo)
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# System packages
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget git curl ca-certificates \
        build-essential gcc g++ \
        libssl-dev zlib1g-dev \
        ninja-build \
    && rm -rf /var/lib/apt/lists/*

# ── pixi installation ─────────────────────────────────────────────────────────
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:${PATH}"

# ── workspace preparation ───────────────────────────────────────────────────
WORKDIR /workspace/phd

# Copy the unified manifest and lock file (shared across all projects)
COPY pixi.toml pixi.lock ./

# Install the specific environment for this sub-project
RUN pixi install -e saprot-env --frozen

# ── environment variables ──────────────────────────────────────────────────────
ENV CONDA_PREFIX=/workspace/phd/.pixi/envs/saprot-env \
    PATH="/workspace/phd/.pixi/envs/saprot-env/bin:${PATH}" \
    CUDA_HOME="/workspace/phd/.pixi/envs/saprot-env" \
    LD_LIBRARY_PATH="/workspace/phd/.pixi/envs/saprot-env/lib:${LD_LIBRARY_PATH}" \
    TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"

# Run any post-install setup tasks (if applicable)
RUN if /root/.pixi/bin/pixi task list -e saprot-env | grep -q 'install-git-deps'; then \
      /root/.pixi/bin/pixi run -e saprot-env install-git-deps; \
    fi

# ── project source ──────────
COPY . .

# Environment routing to the subproject
ENV PYTHONPATH=/workspace/phd/SaProt \
    PROJECT_ROOT=/workspace/phd/SaProt \
    HF_HOME=/workspace/phd/SaProt/.cache/huggingface \
    TRANSFORMERS_CACHE=/workspace/phd/SaProt/.cache/huggingface/hub \
    WANDB_MODE=offline

RUN mkdir -p /workspace/phd/SaProt/.cache/huggingface /workspace/phd/SaProt/checkpoints

WORKDIR /workspace/phd/SaProt

# Entrypoint that automatically hooks into the Pixi environment
RUN echo "#!/bin/bash\nexec /root/.pixi/bin/pixi run -e saprot-env \"\$@\"" > /workspace/phd/entrypoint_saprot.sh \
    && chmod +x /workspace/phd/entrypoint_saprot.sh

ENTRYPOINT ["/workspace/phd/entrypoint_saprot.sh"]
CMD ["bash"]
