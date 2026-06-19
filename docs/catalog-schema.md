# Plant Catalog Schema (Workstream A)

## Overview

The plant catalog is a bundled JSON dataset of common houseplants. It is the knowledge base for species identification, care sheet generation, and problem diagnosis. The dataset is small enough to version with the app (~50 species) and update via CloudKit pushes.

## JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "PlantCatalog",
  "description": "Dataset of common houseplant species for the Verdigris app",
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "id": {
        "description": "Unique identifier (UUID string)",
        "type": "string",
        "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
      },
      "commonName": {
        "description": "Common name in English (also the primary display name)",
        "type": "string",
        "examples": ["Monstera", "Snake Plant", "Pothos"]
      },
      "scientificName": {
        "description": "Binomial scientific name",
        "type": "string",
        "examples": ["Monstera deliciosa", "Dracaena trifasciata", "Epipremnum aureum"]
      },
      "lightNeeds": {
        "description": "Light requirement description",
        "type": "string",
        "enum": ["low", "medium low", "medium", "medium bright", "bright indirect", "direct"]
      },
      "wateringInterval": {
        "description": "Default watering interval in days (baseline, adjusted by placement + season + climate)",
        "type": "integer",
        "minimum": 1,
        "maximum": 60
      },
      "soilType": {
        "description": "Recommended soil type",
        "type": "string",
        "examples": ["Well-draining potting mix", "Cactus mix", "Orchid bark"]
      },
      "humidityRange": {
        "description": "Ideal humidity range description",
        "type": "string",
        "enum": ["low", "low-medium", "medium", "medium-high", "high"]
      },
      "toxicity": {
        "description": "Toxicity to pets/humans",
        "type": "string",
        "enum": ["non-toxic", "mild", "moderate", "severe"]
      },
      "growthHabit": {
        "description": "Growth form",
        "type": "string",
        "enum": ["upright", "trailing", "climbing", "rosette", "bushy"]
      },
      "commonIssues": {
        "description": "List of common problems for this species",
        "type": "array",
        "items": {
          "type": "string"
        },
        "examples": [
          ["overwatering", "yellow leaves", "brown tips"],
          ["spider mites", "root rot"]
        ]
      },
      "imageURLs": {
        "description": "Reference image URLs (credited, licensed for use)",
        "type": "array",
        "items": {
          "type": "string",
          "format": "uri"
        }
      },
      "commonNamesLocalized": {
        "description": "Localized common names keyed by language code",
        "type": "object",
        "properties": {
          "en": { "type": "string" },
          "es": { "type": "string" }
        },
        "required": ["en", "es"]
      }
    },
    "required": ["id", "commonName", "wateringInterval", "commonNamesLocalized"]
  }
}
```

## File Location

`app/Resources/Catalog/catalog.json`

## Image Source / Licensing

**Approach:** Images are not bundled with the app binary. Image URLs point to public domain / Creative Commons sources:

1. **Wikimedia Commons** — Public domain or CC-BY / CC-BY-SA images of houseplants
2. **iNaturalist** — Research-grade observations with CC-BY-NC licenses (in-app attribution required)

Each entry's `imageURLs` field includes the source URL and a `credit` string for display in the attribution footer.

**Legal note:** All images must be verified for license compatibility before inclusion. The app includes an "Image Credits" screen in Settings showing full attributions.

## Initial Species List (Phase 1-2 target)

1. Monstera (Monstera deliciosa)
2. Snake Plant (Dracaena trifasciata)
3. Pothos (Epipremnum aureum)
4. Fiddle Leaf Fig (Ficus lyrata)
5. Peace Lily (Spathiphyllum wallisii)
6. Spider Plant (Chlorophytum comosum)
7. ZZ Plant (Zamioculcas zamiifolia)
8. English Ivy (Hedera helix)
9. Aloe Vera (Aloe barbadensis miller)
10. Boston Fern (Nephrolepis exaltata)
11. Rubber Plant (Ficus elastica)
12. Calathea (Calathea orbifolia)
13. Philodendron (Philodendron hederaceum)
14. Chinese Evergreen (Aglaonema commutatum)
15. Bird of Paradise (Strelitzia reginae)

## Data Authoring Workflow

1. Write entries in the JSON format above
2. Validate against schema
3. Add to `app/Resources/Catalog/catalog.json`
4. Update localized strings in `Localizable.xcstrings`
