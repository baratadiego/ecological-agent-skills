# Análise Geral do Repositório — ecological-agent-skills
<!-- Date: 2026-04-03 | Version analyzed: v3.1.0 (main, 2026-03-28) — confirmed identical to GitHub -->

---

## 1. QUALIDADE DO CÓDIGO

### Pontos fortes

- **Logging padronizado e robusto** em todas as 17 skills (Python e R): mesmo formato `[TIMESTAMP] [LEVEL] [SKILL_NAME]`, com funções `log_step()`, `log_decision()` e `log_error()` consistentes. Cada decisão paramétrica é registrada com justificativa (`DECISION | var = val | why`). Isso é incomum em projetos ecológicos e eleva muito a rastreabilidade.
- **Tratamento de erros detalhado**: toda exceção inclui "Probable cause" e "Previous skill", permitindo que um agente de IA diagnostique falhas automaticamente sem intervenção humana. Padrão profissional.
- **Precondition checks** no início de cada script: verificam se os arquivos de entrada existem antes de processar, com mensagem diagnóstica que aponta qual etapa anterior falhou.
- **Modularidade**: cada skill tem SKILL.md, scripts, resources e examples separados. O `SKILL_INDEX.json` cataloga inputs, outputs, decision_points e dependências de forma estruturada.
- **Testes automatizados**: suite pytest com 28+ testes. Os testes validam URLs, schemas Darwin Core, parsers de fontes (GBIF, iNat, eBird, OBIS), helpers de metadados — sem fazer requisições reais.
- **Bilíngue** (Python + R): cobre os dois ecossistemas dominantes da ecologia computacional.

### Problemas identificados

| Problema | Localização | Criticidade |
|----------|-------------|-------------|
| `WORLDCLIM_BASE` URL desatualizada (domínio `biogeo.ucdavis.edu` encerrado) | `download_predictors.py` | ALTA — **já corrigido e commitado** (v3.1.0) |
| Scripts R de SDM (`run_ensemble_sdm.R`, `tune_maxnet.R`) são **scaffolds incompletos** — contêm estrutura mas o corpo central está vazio | `skills/species-distribution-modeling/scripts/` | ALTA — presente no main atual |
| `SKILL_INDEX.json` sem campo `primary_script` que aponte o executável principal por skill | `SKILL_INDEX.json` | MÉDIA |
| Threshold de colinearidade inconsistente: `SKILL_INDEX.json` define `pearson_correlation_max: 0.7`, mas `SKILL.md` cita `|r| > 0.7` como flag — não como remoção automática | Documentação vs implementação | BAIXA |
| Português/inglês misturados nos logs dos scripts R (ex: `"Analisar argumentos"`, `"Criar output directory"`) | Scripts R de todas as skills | BAIXA |

---

## 2. EFICIÊNCIA COMPUTACIONAL

### Pontos fortes

- Scripts R usam **`terra`** (C++ vectorised): `extract()`, `app()`, `writeRaster()` são operações nativas, muito mais rápidas que loops Python.
- `download_predictors.R` usa **`geodata`** (pacote R) para WorldClim/CHELSA — gere mirrors automaticamente.
- `download_predictors.py` implementa pre-test de BIO1 antes de tentar 19 downloads (padrão correto).
- Estrutura de dependências bem definida no `SKILL_INDEX.json` evita reprocessamento desnecessário.

### Problemas identificados

| Problema | Impacto |
|----------|---------|
| `download_predictors.py` baixa 19 arquivos CHELSA **sequencialmente** (~17 min) — sem paralelismo | Escalabilidade limitada |
| `stack_and_extract.R` carrega todos os rasters em memória sem paginação — pode falhar com CHELSA ~1 km em máquinas com < 16 GB RAM | Risco real com resolução nativa |
| Scripts Python de SDM fazem extração de raster **pixel a pixel em loop puro** — 100–1000× mais lento que `terra::extract()` | Crítico para multi-espécies |
| Sem caching de preditores já baixados (re-executa downloads mesmo se arquivos existem) | Redundância em testes e re-runs |

---

## 3. APLICABILIDADE E USO

### Pontos fortes

- **17 skills + 13 workflows** cobrem praticamente todo o ciclo de análise ecológica.
- Arquitetura de **trigger keywords + decision_points** no `SKILL_INDEX.json` é ideal para um agente LLM selecionar a skill certa automaticamente.
- **Templates prontos**: `params.yaml`, `invoke-skill.md`, `invoke-workflow.md`, checklists pré/pós-análise.
- **Exemplos trabalhados** (6 casos reais): onça-pintada Amazônia, tamanduá-bandeira Cerrado, BACI impacto de rodovias, ocupação de puma, comunidade de aves, fitoplâncton.

### Problemas identificados

| Problema | Impacto |
|----------|---------|
| Scripts R de SDM são **scaffolds** — o agente pode invocá-los e receber log de sucesso sem nenhuma modelagem real | Comportamento enganoso; alto risco |
| Nenhum script orquestrador integra as etapas end-to-end | Barreira de entrada elevada |
| `SKILL_INDEX.json` não referencia os scripts executáveis — agente não sabe qual script chamar | Lacuna de integração agente↔script |
| 5 skills têm `"called_by_workflows": []` — não integradas a nenhum workflow | Skills isoladas, não utilizáveis via workflow |
| Sem validação de versão de pacotes R — scripts podem falhar silenciosamente | Reprodutibilidade comprometida |

---

## 4. INOVAÇÃO

### Diferenciais genuínos

- **Arquitetura de skill para agente LLM**: estruturar análises ecológicas como "skills" invocáveis por um agente, com `SKILL_INDEX.json` como roteador, `SKILL.md` como especificação e logs diagnosticáveis por IA. Abordagem inédita em ecologia computacional.
- **Logging para debugging por IA**: o padrão `Probable cause` + `Previous skill` foi projetado especificamente para que um LLM leia um log de erro e proponha a correção certa.
- **Cobertura temática excepcional**: occupancy + PVA + conectividade + priorização + SDM + séries temporais + serviços ecossistêmicos num único repositório integrado.
- **Bilinguismo R+Python com paridade de logging**: mesma estrutura de log em ambas as linguagens facilita debugging cruzado.

### Oportunidades de inovação ainda não exploradas

| Oportunidade | Observação |
|---|---|
| **GEE (Google Earth Engine) scripts** | Previsto no CHANGELOG v1.2 mas ausente |
| **Multi-species screening workflow** | Existe no `SKILL_INDEX.json` mas não testado |
| **deep-learning-for-ecology skill** | Previsto no CHANGELOG v2.0 — CNNs para armadilhas fotográficas |
| **Integração com Zenodo / OSF / Dryad** | Lacuna de reprodutibilidade científica |

---

## 5. QUALIDADE CIENTÍFICA

### Por skill — avaliação de completude metodológica

| Skill | Documentação | Scripts R | Scripts Python | Qualidade metodológica |
|---|---|---|---|---|
| ecological-data-foundation | Completa | Implementados + CoordinateCleaner | Implementados | **Alta** |
| geoprocessing-for-ecology | Completa | terra + geodata | rasterio | **Alta** — URL WorldClim corrigida |
| predictive-modeling-best-practices | Completa | Recursos sem script principal | parcial | **Média** |
| species-distribution-modeling | Completa | **Scaffolds incompletos** | RF+BRT (sem MaxEnt) | **Baixa** |
| model-validation-and-uncertainty | Completa | Sem script principal | parcial | **Média** |
| occupancy-and-detection | Completa | Scaffold | — | **Média** |
| biostatistics-workbench | Completa | Scaffold | Implementado | **Média** |
| community-ecology-ordination | Completa | Scaffold | Implementado | **Média** |
| ecological-impact-assessment | Completa | Scaffold | — | **Média** |
| environmental-time-series | Completa | Scaffold | — | **Média** |
| ecosystem-services-assessment | Completa | Scaffold | — | **Média** |
| reproducible-ecology-pipeline | Completa | — | — | **Alta** (documentação) |
| camera-trap-processing | Completa | camtrapR | Implementado | **Alta** — não integrado a workflows |
| acoustic-monitoring | Completa | — | Implementado | **Alta** — não integrado |
| landscape-connectivity | Completa | Circuitscape | — | **Alta** — não integrado |
| population-viability-analysis | Completa | matrix models | — | **Alta** — não integrado |
| spatial-prioritization | Completa | prioritizr | — | **Alta** — não integrado |

### Problema estrutural: dualidade Python+R

| Consequência | Detalhes |
|---|---|
| Scripts R de SDM são scaffolds → pipeline real só existe em Python | Python carece de MaxEnt, blockCV, MESS real — os mais críticos |
| Usuário/agente não sabe qual linguagem usar | SKILL.md lista ambas sem hierarquia clara |
| Scripts R implementados (v2.0 skills) são mais completos que os da v1.0 | Inconsistência interna de maturidade |
| Testes automatizados existem só em Python | Scripts R sem cobertura de testes |

---

## 6. AJUSTES METODOLÓGICOS PRIORITÁRIOS

### Fase 1 — Críticos (afetam usabilidade imediata)

1. **Completar `run_ensemble_sdm.R`** — implementar corpo completo: MaxEnt (ENMeval), BRT, RF, blockCV para validação espacial, TSS + AUC, mapas de incerteza (desvio padrão do ensemble), curvas de resposta.

2. **Completar `tune_maxnet.R`** — já tem estrutura ENMeval; implementar grid RM × FC, critério OR_AICc, exportação de parâmetros ótimos.

3. **Adicionar `primary_script_r` / `primary_script_py` ao `SKILL_INDEX.json`** — para que o agente saiba exatamente qual arquivo executar para cada skill.

### Fase 2 — Importantes (qualidade e consistência)

4. **Integrar as 5 skills v2.0 em workflows** — `camera-trap-processing`, `acoustic-monitoring`, `landscape-connectivity`, `population-viability-analysis`, `spatial-prioritization` têm `"called_by_workflows": []`.

5. **Padronizar idioma dos logs R para inglês** — mensagens em português e inglês misturadas nos scripts R das skills v1.0.

6. **Criar `check_packages.R`** — equivalente ao `check_packages.py`, valida versões mínimas de `terra`, `ENMeval`, `CoordinateCleaner`, `blockCV`, `dismo`.

7. **Ampliar cobertura de testes R** — `tests/r/` tem arquivos mas cobertura mínima. Skills críticas (SDM, occupancy) precisam de `testthat`.

### Fase 3 — Melhorias

8. **Adicionar caching de downloads** — verificar se arquivos já existem antes de baixar em `download_predictors.py` e `download_predictors.R`.

9. **GEE scripts** — previsto no roadmap v1.2; abriria análise de séries temporais MODIS/Landsat sem download local.

10. **Integração com plataformas de publicação** — Zenodo / OSF / Dryad para arquivamento reproduzível de outputs.

---

## 7. RESUMO EXECUTIVO

| Dimensão | Nota | Justificativa |
|----------|------|---------------|
| **Qualidade do código** | 8/10 | Logging e tratamento de erros excelentes; scaffolds incompletos penalizam |
| **Eficiência computacional** | 7/10 | R com terra é eficiente; Python SDM pipeline tem gargalos em extração |
| **Aplicabilidade e uso** | 6/10 | Cobertura temática excepcional; scaffolds incompletos e falta de orquestrador reduzem usabilidade real |
| **Inovação** | 9/10 | Arquitetura skill+agente+logging diagnóstico é genuinamente inovadora para ecologia computacional |
| **Qualidade científica** | 6/10 | Documentação metodológica exemplar; implementação R incompleta em skills centrais |
| **MÉDIA** | **7.2/10** | Repositório com excelente potencial, limitado pela lacuna entre documentação e implementação |

```
FASE 1 — Completar o que existe:
  ├── Completar run_ensemble_sdm.R (MaxEnt + BRT + RF + blockCV + TSS)
  ├── Completar tune_maxnet.R (ENMeval RM×FC + OR_AICc)
  └── Adicionar primary_script_r / primary_script_py no SKILL_INDEX.json

FASE 2 — Integrar e conectar:
  ├── Integrar 5 skills v2.0 em workflows
  ├── Padronizar idioma dos logs R (inglês)
  └── Adicionar check_packages.R

FASE 3 — Expandir:
  ├── GEE script equivalents (Roadmap v1.2)
  ├── Testes R com testthat
  └── Caching de downloads
```
