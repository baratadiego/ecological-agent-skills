# Global Examples Index

Complete inventory of all worked examples in the ecological-agent-skills repository, with geographic and thematic coverage analysis.

---

## Example Inventory

| # | Example | Species / System | Region | Continent | Biome | Skill / Workflow | Analysis Type | Data Source | DOI / URL |
|---|---------|-----------------|--------|-----------|-------|-----------------|---------------|-------------|-----------|
| 1 | [Jaguar SDM](../examples/sdm/jaguar_amazon_example.md) | *Panthera onca* | Brazilian Amazon | South America | Tropical moist forest | run-sdm-study | SDM | GBIF, SpeciesLink, WorldClim | doi:10.15468/dl.xxxxx |
| 2 | [Giant Anteater SDM](../examples/sdm/anteater_cerrado_example.md) | *Myrmecophaga tridactyla* | Cerrado, Brazil | South America | Tropical savanna | run-sdm-study | SDM | GBIF, WorldClim, MapBiomas | doi:10.15468/dl.xxxxx |
| 3 | [Grey Wolf Recolonization](../examples/sdm/wolf_recolonization_europe_example.md) | *Canis lupus* | Western Europe | Europe | Temperate forest / Mediterranean | run-sdm-study | SDM + conflict analysis | GBIF, EuroLargeCarnivores, WorldClim, Corine LC | doi:10.15468/dl.xxxxx |
| 4 | [Koala Climate Change](../examples/sdm/koala_climate_change_example.md) | *Phascolarctos cinereus* | Eastern Australia | Oceania | Temperate woodland | run-sdm-study | SDM + future projection + MOP | GBIF, ALA, WorldClim, CMIP6 | doi:10.15468/dl.xxxxx |
| 5 | [Red Fox Reproducible](../examples/reproducible/whittaker_biome_sdm_example.md) | *Vulpes vulpes* | Holarctic (global) | Multi-continent | Multiple | run-sdm-study | SDM (fully reproducible) | GBIF, WorldClim | doi:10.15468/dl.example |
| 6 | [Bird Community — Atlantic Forest](../examples/community/bird_landuse_example.md) | 127 bird species | Atlantic Forest, Brazil | South America | Tropical moist forest | analyze-community-structure | Community ecology | Field surveys | — |
| 7 | [Phytoplankton — Amazon Reservoirs](../examples/community/phytoplankton_reservoir_example.md) | Phytoplankton assemblages | Amazon basin reservoirs | South America | Tropical moist forest (aquatic) | analyze-community-structure | Community ecology | Field surveys | — |
| 8 | [Reef Fish — Indo-Pacific](../examples/community/reef_fish_indopacific_example.md) | 987 reef fish species | Indo-Pacific coral reefs | Asia / Oceania | Marine coral reef | analyze-community-structure | Community ecology (beta diversity) | Reef Life Survey | doi:10.1038/sdata.2014.7 |
| 9 | [Arctic Tundra Vegetation](../examples/community/arctic_tundra_vegetation_example.md) | Tundra vegetation | Greenland, northern Canada | North America / Europe | Arctic tundra | analyze-community-structure + environmental-time-series | Time series + community shift | MODIS, ERA5-Land, AVA | — |
| 10 | [BACI Road Impact — Birds](../examples/impact/baci_road_example.md) | Birds (Atlantic Forest) | Atlantic Forest, Brazil | South America | Tropical moist forest | assess-ecological-impact | BACI impact assessment | Field surveys | — |
| 11 | [Ecosystem Services — Atlantic Forest](../examples/impact/ecosystem_services_atlantic_example.md) | Atlantic Forest remnants | São Paulo, Brazil | South America | Tropical moist forest | assess-ecosystem-services | Ecosystem services | MapBiomas | — |
| 12 | [Forest Loss — Borneo](../examples/impact/forest_loss_borneo_timeseries_example.md) | Tropical rainforest | Borneo (Malaysia, Indonesia) | Asia | Tropical moist forest | assess-ecological-impact | BFAST + fragmentation + BACI | Hansen GFC, MODIS | doi:10.1126/science.1244693 |
| 13 | [Puma Occupancy — Camera Traps](../examples/occupancy/puma_camera_example.md) | *Puma concolor* | Atlantic Forest, Brazil | South America | Tropical moist forest | run-occupancy-analysis | Occupancy modeling | Camera traps | — |
| 14 | [Snow Leopard Occupancy — Himalayas](../examples/occupancy/snow_leopard_himalayas_example.md) | *Panthera uncia* | Central Himalayas (Nepal/India) | Asia | Alpine / montane | run-occupancy-analysis | Occupancy modeling | Camera traps, literature | doi:10.2193/0091-7648 |

---

## Coverage Summary

### Continents Represented

| Continent | Examples | Example IDs |
|-----------|---------|-------------|
| South America | 6 | 1, 2, 6, 7, 10, 11 |
| Europe | 2 | 3, 9 (Greenland) |
| Asia | 3 | 8, 12, 14 |
| Oceania | 2 | 4, 8 (Indo-Pacific overlap) |
| North America | 2 | 5 (Holarctic), 9 (Canada) |
| Africa | 1 | 5 (Holarctic — includes N. Africa margin) |

All 6 inhabited continents are covered. Africa has minimal direct representation (only via the Holarctic red fox range), but the repository's skills and workflows are globally applicable.

### Biomes Represented

| Biome | Examples | n |
|-------|---------|---|
| Tropical moist forest | 1, 2, 6, 7, 10, 11, 12, 13 | 8 |
| Tropical savanna (Cerrado) | 2 | 1 |
| Temperate forest | 3 | 1 |
| Temperate woodland | 4 | 1 |
| Mediterranean | 3 | 1 |
| Marine coral reef | 8 | 1 |
| Arctic tundra | 9 | 1 |
| Alpine / montane | 14 | 1 |
| Multiple (Holarctic) | 5 | 1 |

### Taxonomic Groups

| Group | Species / System | Examples |
|-------|-----------------|---------|
| Mammals | Jaguar, anteater, wolf, koala, fox, puma, snow leopard | 1, 2, 3, 4, 5, 13, 14 |
| Birds | Atlantic Forest bird community | 6, 10 |
| Fish | Indo-Pacific reef fish (987 spp.) | 8 |
| Plants | Arctic tundra vegetation | 9 |
| Phytoplankton | Amazon reservoir assemblages | 7 |
| Ecosystem (forest) | Borneo tropical forest, Atlantic Forest remnants | 11, 12 |

### Analysis Types

| Analysis | Examples | n |
|----------|---------|---|
| SDM (species distribution modeling) | 1, 2, 3, 4, 5 | 5 |
| Community ecology (ordination, diversity) | 6, 7, 8 | 3 |
| Occupancy modeling | 13, 14 | 2 |
| BACI impact assessment | 10, 12 | 2 |
| Ecosystem services | 11 | 1 |
| Time series (NDVI, BFAST) | 9, 12 | 2 |
| Climate change projection | 4 | 1 |
| Conflict / land-use overlay | 3 | 1 |
| Fragmentation (MESH) | 12 | 1 |

### Workflows Used

| Workflow | Examples |
|----------|---------|
| run-sdm-study | 1, 2, 3, 4, 5 |
| analyze-community-structure | 6, 7, 8, 9 |
| run-occupancy-analysis | 13, 14 |
| assess-ecological-impact | 10, 12 |
| assess-ecosystem-services | 11 |
| analyze-environmental-change | 9 |

---

## Coverage Gaps and Notes

- **Africa**: Represented only through the Holarctic red fox example. All skills and workflows are applicable to African taxa and ecosystems — users are encouraged to contribute African case studies.
- **Acoustic monitoring / eDNA**: No worked example yet. The `acoustic-monitoring` skill includes decision tables and scripts but awaits a full example.
- **PVA**: No worked example yet. The `population-viability-analysis` skill includes Leslie matrix scripts and IUCN Criterion E guidance.
- **Spatial prioritization**: No worked example yet. The `spatial-prioritization` skill includes prioritizr scripts and 30x30 target guidance.
- **Connectivity**: No worked example yet. The `landscape-connectivity` skill includes IIC/PC/Circuitscape scripts.

These gaps represent opportunities for future examples. The skill documentation and scripts are complete and functional — examples provide illustration, not implementation.
