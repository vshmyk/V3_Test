# Abio Pre-Export Migration Sizing

Generated: 2026-07-03 04:06:09 +00:00

## Important Caveat

This report is based on library metadata and the non-authoritative PBL binary object-name scan. It is useful for early prioritization and sizing conversations, but the full PowerBuilder source export remains required before final estimates.

## Module Sizing

| Module | Wave | Risk | Libraries | Size MB | Object Hints | DataWindows | Windows | Complexity Score |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| PowerBuilder Framework | 1 | Medium/High | 14 | 25.72 | 305 | 39 | 32 | 1987.2 |
| Reports | 5 | High | 9 | 39.62 | 463 | 325 | 29 | 1847.9 |
| Shared Foundation | 1 | High | 3 | 40.71 | 522 | 307 | 49 | 1302.8 |
| Job Cost | 5 | High | 2 | 44.69 | 342 | 265 | 30 | 868.3 |
| Payables | 5 | High | 2 | 37.13 | 335 | 239 | 33 | 846 |
| Receivables | 5 | Medium/High | 2 | 37.17 | 365 | 256 | 28 | 835.7 |
| Payroll | 5 | Very High | 2 | 48.48 | 262 | 206 | 16 | 794.2 |
| Administration | 3 | Low/Medium | 2 | 32.68 | 414 | 188 | 48 | 768.9 |
| General Ledger | 5 | Very High | 2 | 15.48 | 138 | 110 | 10 | 541.6 |
| Equipment | 4 | Medium | 2 | 20.86 | 188 | 135 | 19 | 487 |
| Human Resources | 4 | Medium | 2 | 7.21 | 104 | 69 | 8 | 329.7 |
| Dashboard | 2 | Low/Medium | 2 | 3.03 | 52 | 32 | 12 | 191.3 |
| Inventory | 4 | Medium | 1 | 4.41 | 40 | 22 | 8 | 152.6 |
| Project Management | 4 | Medium | 1 | 1.98 | 32 | 19 | 4 | 131.8 |

## Largest Library Hotspots

| Library | Module | Risk | Size MB | Object Hints | DataWindows | Windows | Complexity Score |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| shared_tables.pbl | Shared Foundation | High | 18.53 | 296 | 186 | 26 | 637.9 |
| receivables.pbl | Receivables | Medium/High | 23.96 | 305 | 200 | 25 | 621.6 |
| payables.pbl | Payables | High | 25.28 | 276 | 181 | 32 | 613.6 |
| jobcost.pbl | Job Cost | High | 21.17 | 238 | 163 | 28 | 548.5 |
| payroll.pbl | Payroll | Very High | 27.54 | 183 | 129 | 15 | 490.2 |
| administration_menu.pbl | Administration | Low/Medium | 22.42 | 197 | 133 | 21 | 410.9 |
| table.pbl | Shared Foundation | High | 16.29 | 161 | 109 | 9 | 410.1 |
| abio.pbl | Administration | Low/Medium | 10.26 | 217 | 55 | 27 | 358 |
| reports.pbl | Reports | High | 5.64 | 175 | 60 | 10 | 354.3 |
| equipment.pbl | Equipment | Medium | 13.6 | 149 | 98 | 17 | 340.7 |
| general_ledger.pbl | General Ledger | Very High | 8.83 | 104 | 80 | 8 | 328.5 |
| reports_jc.pbl | Job Cost | High | 23.52 | 104 | 102 | 2 | 319.8 |
| reports_pr.pbl | Payroll | Very High | 20.94 | 79 | 77 | 1 | 304 |
| pfemain.pbl | PowerBuilder Framework | Medium/High | 0.46 | 88 | 1 | 8 | 259.7 |
| framework.pbl | Shared Foundation | High | 5.89 | 65 | 12 | 14 | 254.8 |
| reports_cc.pbl | Reports | High | 13.19 | 66 | 64 | 2 | 246 |
| human_resources.pbl | Human Resources | Medium | 6.78 | 98 | 65 | 6 | 243.2 |
| pfeapsrv.pbl | PowerBuilder Framework | Medium/High | 0.35 | 76 | 0 | 8 | 243.1 |
| reports_ut.pbl | Reports | High | 9.84 | 63 | 52 | 7 | 242.2 |
| reports_ap.pbl | Payables | High | 11.85 | 59 | 58 | 1 | 232.4 |

## Reading The Score

The complexity score is a rough pre-export ranking. It combines object-name hint counts, DataWindow count, window count, user object count, PBL size, and known business risk. Higher values mean the area probably deserves more discovery and migration planning effort.

## Output Files

- module-sizing.csv
- library-sizing.csv
