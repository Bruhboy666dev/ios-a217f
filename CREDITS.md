# Credits

- **Schoosh** — Original A13 base and Mali bring-up that this port builds on: [simpleXNU/ios-a135f](https://github.com/simpleXNU/ios-a135f).
- **Bruhboy666dev** — A21s adaptation of the upstream Mali GL work and native display integration: [commit 65257ea](https://github.com/Bruhboy666dev/ios-a217f/commit/65257ea15b6a8b94e5b0afa8b0a8735179dd4781). The original commit author metadata remains intact.
- **SamiOs-21s contributors** — A21s-tested Exynos 850 Mali-G52/Panfrost findings that informed the A217F path. The A21s kernel path checks the S-Boot GPU power state and avoids writing PMU/CMU registers: [SamiOs-21s](https://github.com/SuperProgramer64/SamiOs-21s).
- **HakiOS and A32 contributors** — the Mali kernel/RedwoodMali and Panfrost integration lineage used by SamiOs-21s; retain the upstream project licenses and notices.
- **Mesa contributors** — Mesa and Panfrost components; see their upstream license and copyright notices.
