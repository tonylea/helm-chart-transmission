# Changelog

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## [1.1.0](https://github.com/tonylea/helm-chart-transmission/compare/v1.0.0...v1.1.0) (2026-11-23)

### Features

* let the incomplete folder be left out of the chown, for storage that refuses one ([12386bc](https://github.com/tonylea/helm-chart-transmission/commit/12386bc29d801cfe6d3087f6e659bedb7fcd8f83))

## 1.0.0 (2026-11-23)

### Features

* deploy Transmission behind Gluetun, with its settings applied at every start ([79fa2f7](https://github.com/tonylea/helm-chart-transmission/commit/79fa2f75490889af146819ef68c47ad4d65c874b))
* let the wrapper set the pod's fsGroup ([07020a7](https://github.com/tonylea/helm-chart-transmission/commit/07020a7f5d6fcbf4c8568c6219999a7a45d6b012))

### Bug Fixes

* chown /run and the chart's volumes before Transmission starts ([5cc70e7](https://github.com/tonylea/helm-chart-transmission/commit/5cc70e73d990415cdb8e77664ef781e56f6e2230))
