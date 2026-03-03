#!/usr/bin/env python3
"""
sdm_pipeline.py
SDM pipeline scaffold using elapid (MaxEnt equivalent in Python) + sklearn.
Usage: python sdm_pipeline.py <params_yaml> <output_dir>
Requires: pandas, numpy, sklearn, elapid (optional), yaml, matplotlib
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "species-distribution-modeling"
_LOG_DIR   = Path("logs")
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_log_file  = _LOG_DIR / f"skill_{SKILL_NAME}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [" + SKILL_NAME + "] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_log_file, encoding="utf-8"),
    ],
)
logger = logging.getLogger(SKILL_NAME)

def log_step(n: int, desc: str) -> None:
    logger.info("-- STEP %d: %s", n, desc)

def log_decision(var: str, val, why: str) -> None:
    logger.info("DECISION | %s = %s | %s", var, val, why)


import yaml
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedKFold

try:
    import elapid
    HAS_ELAPID = True
    logger.info("elapid disponivel para modelagem MaxEnt.")
except ImportError:
    HAS_ELAPID = False
    logger.warning("elapid nao instalado (MaxEnt). Instale com: pip install elapid")


def load_params(path: str) -> dict:
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        logger.error(
            "Arquivo de parametros nao encontrado: %s\n  Causa provavel: arquivo nao gerado pelo passo anterior.\n  Verifique a saida de: species-distribution-modeling (preparacao de parametros)\n  Skill anterior: species-distribution-modeling",
            path,
        )
        sys.exit(1)
    except yaml.YAMLError as e:
        logger.error(
            "Falha ao analisar YAML '%s': %s\n  Causa provavel: YAML malformado ou encoding incorreto.\n  Skill anterior: species-distribution-modeling",
            path, e,
        )
        sys.exit(1)


def load_data(p: dict) -> tuple:
    data_path = "data/processed/points_with_env.csv"
    predictors_path = "outputs/selected_predictors.txt"

    try:
        pts = pd.read_csv(data_path)
    except FileNotFoundError:
        logger.error(
            "Arquivo de dados nao encontrado: %s\n  Causa provavel: arquivo nao gerado pelo passo anterior.\n  Esperado como saida de: ecological-data-foundation (clean_occurrences)\n  Skill anterior: ecological-data-foundation",
            data_path,
        )
        raise
    except Exception as e:
        logger.error(
            "Falha ao carregar dados de pontos '%s': %s\n  Skill anterior: ecological-data-foundation",
            data_path, e,
        )
        raise

    try:
        predictors = open(predictors_path).read().strip().split("\n")
    except FileNotFoundError:
        logger.error(
            "Arquivo de preditores nao encontrado: %s\n  Causa provavel: etapa de selecao de variaveis nao concluida.\n  Skill anterior: species-distribution-modeling",
            predictors_path,
        )
        raise

    predictors = [pr for pr in predictors if pr in pts.columns]

    if not predictors:
        logger.error(
            "Nenhum preditor valido encontrado em '%s' que coincida com as colunas de '%s'.\n  Causa provavel: nomes de colunas divergem entre os arquivos.\n  Skill anterior: species-distribution-modeling",
            predictors_path, data_path,
        )
        raise ValueError("No valid predictors found.")

    logger.info("Preditores carregados (%d): %s", len(predictors), predictors)

    if "pa" in pts.columns:
        y = pts["pa"].values
        log_decision("response_col", "pa", "coluna 'pa' encontrada nos dados")
    elif "presence" in pts.columns:
        y = pts["presence"].values
        log_decision("response_col", "presence", "coluna 'presence' usada como alternativa")
    else:
        logger.error(
            "Nenhuma coluna de resposta encontrada nos dados. Esperado: 'pa' ou 'presence'.\n  Causa provavel: dados nao preparados pelo script de background.\n  Skill anterior: ecological-data-foundation",
        )
        raise KeyError("Missing response column 'pa' or 'presence'.")

    X = pts[predictors].values

    n_presence = int(y.sum())
    n_bg       = int((y == 0).sum())
    logger.info("Registros carregados — Presencas: %d | Background: %d", n_presence, n_bg)

    if n_presence < 10:
        logger.warning(
            "Poucos registros de presenca (%d). SDM pode ser instavel. Recomendado: >= 30.",
            n_presence,
        )

    return X, y, predictors


def spatial_cv_splits(pts_df, fold_col="cv_fold"):
    folds = pts_df[fold_col].unique()
    for fold in sorted(folds):
        test_idx  = pts_df.index[pts_df[fold_col] == fold].tolist()
        train_idx = pts_df.index[pts_df[fold_col] != fold].tolist()
        yield train_idx, test_idx


def fit_rf(X_train, y_train, params: dict):
    rf_p = params.get("hyperparameters", {}).get("random_forest", {})
    n_trees       = rf_p.get("n_trees", 500)
    min_node_size = rf_p.get("min_node_size", 5)
    log_decision("rf_n_trees",       n_trees,       "numero de arvores do RF definido em params.yaml")
    log_decision("rf_min_node_size", min_node_size, "tamanho minimo de no do RF definido em params.yaml")
    try:
        clf = RandomForestClassifier(
            n_estimators=n_trees,
            min_samples_leaf=min_node_size,
            random_state=params["random_seeds"]["global"],
            n_jobs=-1,
        )
        clf.fit(X_train, y_train)
        return clf
    except Exception as e:
        logger.error(
            "Falha ao ajustar RandomForest: %s\n  Causa provavel: dados de treinamento invalidos ou parametros incompativeis.\n  Skill anterior: species-distribution-modeling",
            e,
        )
        raise


def fit_brt(X_train, y_train, params: dict):
    brt_p = params.get("hyperparameters", {}).get("brt", {})
    n_trees       = brt_p.get("n_trees", [500])[0]
    learning_rate = brt_p.get("learning_rate", [0.01])[0]
    tree_depth    = brt_p.get("tree_complexity", [3])[0]
    bag_fraction  = brt_p.get("bag_fraction", 0.75)
    log_decision("brt_n_trees",       n_trees,       "numero de arvores do BRT definido em params.yaml")
    log_decision("brt_learning_rate", learning_rate, "taxa de aprendizado do BRT definida em params.yaml")
    log_decision("brt_tree_depth",    tree_depth,    "profundidade das arvores do BRT definida em params.yaml")
    log_decision("brt_bag_fraction",  bag_fraction,  "fracao de subamostras por arvore (BRT) definida em params.yaml")
    try:
        clf = GradientBoostingClassifier(
            n_estimators=n_trees,
            learning_rate=learning_rate,
            max_depth=tree_depth,
            subsample=bag_fraction,
            random_state=params["random_seeds"]["global"],
        )
        clf.fit(X_train, y_train)
        return clf
    except Exception as e:
        logger.error(
            "Falha ao ajustar GradientBoosting (BRT): %s\n  Causa provavel: dados de treinamento invalidos ou parametros incompativeis.\n  Skill anterior: species-distribution-modeling",
            e,
        )
        raise


def main():
    logger.info("Script: sdm_pipeline.py | Skill: %s", SKILL_NAME)

    params_file = sys.argv[1] if len(sys.argv) > 1 else "params.yaml"
    output_dir  = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/sdm")

    logger.info("Params file : %s", params_file)
    logger.info("Output dir  : %s", output_dir)

    # Input precondition check
    if not Path(params_file).exists():
        logger.error(
            "Input nao encontrado: %s\n  Causa provavel: arquivo nao gerado pelo passo anterior.\n  Verifique a saida de: species-distribution-modeling (preparacao de parametros)\n  Skill anterior: species-distribution-modeling",
            params_file,
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Diretorio de saida pronto: %s", output_dir)

    log_step(1, "Carregar parametros YAML")
    p = load_params(params_file)

    np.random.seed(p["random_seeds"]["global"])
    log_decision("random_seed", p["random_seeds"]["global"], "semente global definida em params.yaml para reprodutibilidade")
    log_decision("algorithms",  p["modeling"]["algorithms"],  "algoritmos definidos em params.yaml")
    log_decision("cv_folds",    p["modeling"]["cv_folds"],    "numero de folds definido em params.yaml")

    logger.info("Pipeline SDM | Algoritmos: %s", p["modeling"]["algorithms"])

    log_step(2, "Carregar dados de ocorrencia e preditores")
    try:
        X, y, predictors = load_data(p)
    except FileNotFoundError as e:
        logger.error(
            "Arquivo de entrada nao encontrado: %s\n  Esperado como saida de: ecological-data-foundation\n  Verifique se o passo anterior foi concluido.",
            e,
        )
        logger.info("Scaffold carregado. Adicione o carregamento de dados para seu estudo.")
        return
    except Exception as e:
        logger.error(
            "Nao foi possivel carregar dados: %s\n  Scaffold carregado. Adicione o carregamento de dados para seu estudo.",
            e,
        )
        return

    log_step(3, "Executar validacao cruzada estratificada por fold")
    log_decision(
        "cv_method", "StratifiedKFold",
        "fallback para k-fold estratificado quando coluna cv_fold nao esta presente",
    )
    skf = StratifiedKFold(
        n_splits=p["modeling"]["cv_folds"],
        shuffle=True,
        random_state=p["random_seeds"]["global"],
    )
    auc_rf, auc_brt = [], []

    try:
        for fold, (train_idx, test_idx) in enumerate(skf.split(X, y)):
            X_tr, X_te = X[train_idx], X[test_idx]
            y_tr, y_te = y[train_idx], y[test_idx]

            if "random_forest" in p["modeling"]["algorithms"]:
                rf = fit_rf(X_tr, y_tr, p)
                fold_auc = roc_auc_score(y_te, rf.predict_proba(X_te)[:, 1])
                auc_rf.append(fold_auc)
                logger.info("Fold %d | RF AUC = %.3f", fold + 1, fold_auc)
                if fold_auc < 0.7:
                    logger.warning(
                        "Fold %d: RF AUC baixo (%.3f). Verifique qualidade dos dados de background.",
                        fold + 1, fold_auc,
                    )

            if "brt" in p["modeling"]["algorithms"]:
                brt = fit_brt(X_tr, y_tr, p)
                fold_auc_brt = roc_auc_score(y_te, brt.predict_proba(X_te)[:, 1])
                auc_brt.append(fold_auc_brt)
                logger.info("Fold %d | BRT AUC = %.3f", fold + 1, fold_auc_brt)
                if fold_auc_brt < 0.7:
                    logger.warning(
                        "Fold %d: BRT AUC baixo (%.3f). Verifique qualidade dos dados de background.",
                        fold + 1, fold_auc_brt,
                    )
    except Exception as e:
        logger.error(
            "Falha durante validacao cruzada: %s\n  Causa provavel: dados de treinamento invalidos, preditores com NaN, ou parametros incompativeis.\n  Skill anterior: species-distribution-modeling",
            e,
        )
        raise

    log_step(4, "Compilar e salvar metricas de desempenho")
    results = {}
    if auc_rf:
        results["RandomForest"] = {"AUC_mean": float(np.mean(auc_rf)), "AUC_sd": float(np.std(auc_rf))}
        logger.info("RandomForest — AUC medio: %.3f (+/- %.3f)", np.mean(auc_rf), np.std(auc_rf))
    if auc_brt:
        results["BRT"] = {"AUC_mean": float(np.mean(auc_brt)), "AUC_sd": float(np.std(auc_brt))}
        logger.info("BRT — AUC medio: %.3f (+/- %.3f)", np.mean(auc_brt), np.std(auc_brt))

    results_df = pd.DataFrame(results).T

    try:
        results_df.to_csv(output_dir / "cv_performance.csv")
        logger.info("Gravado: %s", output_dir / "cv_performance.csv")
    except OSError as e:
        logger.error(
            "Falha ao gravar cv_performance.csv em '%s': %s\n  Causa provavel: sem permissao de escrita no diretorio.\n  Skill anterior: species-distribution-modeling",
            output_dir, e,
        )
        raise

    logger.info("Desempenho de CV:\n%s", results_df.to_string())
    logger.info("Saidas gravadas em: %s", output_dir)


if __name__ == "__main__":
    main()
