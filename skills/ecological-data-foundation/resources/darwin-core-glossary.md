# Darwin Core Field Glossary

Essential fields for biodiversity occurrence data following the [Darwin Core standard](https://dwc.tdwg.org/).

## Identity Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `occurrenceID` | string | Globally unique identifier for the occurrence | `urn:uuid:a948571f-...` |
| `catalogNumber` | string | Institution-assigned identifier | `MNRJ-12345` |
| `recordedBy` | string | Observer name(s) | `"Silva, J.R."` |
| `recordNumber` | string | Field number assigned by the observer | `JRS-2023-001` |

## Taxonomic Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `scientificName` | string | Full scientific name with authorship | `Panthera onca (Linnaeus, 1758)` |
| `kingdom` | string | | `Animalia` |
| `phylum` | string | | `Chordata` |
| `class` | string | | `Mammalia` |
| `order` | string | | `Carnivora` |
| `family` | string | | `Felidae` |
| `genus` | string | | `Panthera` |
| `specificEpithet` | string | Species epithet only | `onca` |
| `taxonRank` | string | Lowest rank of the name | `species` |
| `vernacularName` | string | Common name | `jaguar` |
| `taxonID` | string | Taxon identifier in a reference system | `gbif:5219243` |

## Occurrence Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `basisOfRecord` | string | Nature of the record | `HumanObservation`, `PreservedSpecimen`, `MachineObservation` |
| `occurrenceStatus` | string | Presence or absence | `present`, `absent` |
| `individualCount` | integer | Number of individuals | `3` |
| `sex` | string | | `male`, `female`, `undetermined` |
| `lifeStage` | string | | `adult`, `juvenile`, `larva` |
| `behavior` | string | Observed behavior | `foraging` |

## Location Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `decimalLatitude` | float | Latitude in decimal degrees (WGS84) | `-15.7801` |
| `decimalLongitude` | float | Longitude in decimal degrees (WGS84) | `-47.9292` |
| `geodeticDatum` | string | Datum for coordinates | `WGS84` |
| `coordinateUncertaintyInMeters` | float | Radius of coordinate uncertainty | `100` |
| `coordinatePrecision` | float | Decimal places of coordinates | `0.0001` |
| `countryCode` | string | ISO 3166-1 alpha-2 | `BR` |
| `stateProvince` | string | State or province | `Mato Grosso` |
| `county` | string | County or municipality | `Cáceres` |
| `locality` | string | Specific location description | `"Fazenda São José, margem do rio"` |
| `verbatimElevation` | string | Original elevation text | `"850-900 m"` |
| `minimumElevationInMeters` | float | | `850` |
| `maximumElevationInMeters` | float | | `900` |

## Event Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `eventDate` | string | ISO-8601 date or date range | `2023-07-15`, `2023-07/2023-08` |
| `year` | integer | | `2023` |
| `month` | integer | | `7` |
| `day` | integer | | `15` |
| `eventTime` | string | Time of observation | `14:30:00-03:00` |
| `samplingProtocol` | string | Method used | `"point count"`, `"camera trap"` |
| `samplingEffort` | string | Effort description | `"3 nights, 1 trap"` |

## Data Quality Fields

| Field | Type | Description |
|-------|------|-------------|
| `identificationQualifier` | string | Uncertainty in identification (`cf.`, `aff.`) |
| `identifiedBy` | string | Who identified the specimen |
| `dateIdentified` | string | When identification was made |
| `datasetName` | string | Source dataset name |
| `institutionCode` | string | Institution acronym |
| `license` | string | Data license (CC BY 4.0, etc.) |
| `rightsHolder` | string | Owner of the data rights |

## Common Issues and Fixes

| Issue | Detection | Fix |
|-------|-----------|-----|
| Coordinates swapped (lat/lon) | lat > 90 or < -90 | Swap columns |
| Comma as decimal separator | `"-15,78"` | Replace `,` → `.` |
| DMS instead of decimal | `"15°46'48"S"` | Convert to decimal |
| Missing datum | No `geodeticDatum` | Assume WGS84; flag |
| Future date | `eventDate` > today | Flag and investigate |
| Country centroid | Coordinates = known centroid | Flag as `COUNTRY_CENTROID` |
