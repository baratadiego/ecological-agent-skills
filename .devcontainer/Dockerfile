# ecological-agent-skills DevContainer
# Full R + Python geospatial environment
# SPDX-License-Identifier: GPL-3.0-or-later

FROM rocker/geospatial:4.4

LABEL maintainer="Francisco Diego Barros Barata"
LABEL description="ecological-agent-skills: R 4.4 + Python 3.11 + geospatial stack"

# ── System dependencies ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3-pip python3.11-dev \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    libsndfile1 libsndfile1-dev ffmpeg \
    git curl jq nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# ── Python virtual environment ───────────────────────────────────────────────
ENV VIRTUAL_ENV=/opt/venv
RUN python3.11 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# ── Python dependencies ──────────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    pip install --no-cache-dir pytest pytest-cov

# ── R packages (CRAN) ───────────────────────────────────────────────────────
RUN install2.r --error --skipinstalled \
    terra sf dplyr ggplot2 tidyr readr yaml janitor lubridate zoo broom \
    lme4 emmeans MuMIn effectsize corrplot car \
    vegan unmarked gbm randomForest trend \
    igraph ggrepel rgbif geodata \
    CoordinateCleaner blockCV maxnet ENMeval dismo \
    camtrapR overlap circular \
    soundecology tuneR seewave \
    popbio prioritizr highs \
    gdistance \
    forecast strucchange changepoint \
    glmmTMB DHARMa betapart SPEI \
    landscapemetrics \
    rinat auk robis rredlist \
    testthat

# ── Workspace ────────────────────────────────────────────────────────────────
WORKDIR /workspace
ENV PYTHONPATH="/workspace/skills"
ENV R_LIBS_USER="/usr/local/lib/R/site-library"
ENV OMP_NUM_THREADS=4
