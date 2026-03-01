# params_loader.py
# Load project parameters from params.yaml into Python namespace
# Usage: from scripts.params_loader import p, set_seeds
# Requires: pyyaml, numpy, random

import yaml
import random
import os
import numpy as np

PARAMS_FILE = "params.yaml"

def load_params(path: str = PARAMS_FILE) -> dict:
    if not os.path.exists(path):
        raise FileNotFoundError(f"params.yaml not found at: {os.path.abspath(path)}")
    with open(path, "r") as f:
        params = yaml.safe_load(f)
    print(f"params.yaml loaded. Project: {params['project']['name']} | Version: {params['project']['version']}")
    return params

def set_seeds(params: dict) -> None:
    seed = params["random_seeds"]["global"]
    random.seed(seed)
    np.random.seed(seed)
    try:
        import torch
        torch.manual_seed(seed)
    except ImportError:
        pass
    print(f"Random seeds set to: {seed}")

p = load_params()
set_seeds(p)

PROJECT_CRS  = p["spatial"]["project_crs"]
ANALYSIS_CRS = p["spatial"]["analysis_crs"]
CV_FOLDS     = p["modeling"]["cv_folds"]
N_BACKGROUND = p["modeling"]["background_n"]
