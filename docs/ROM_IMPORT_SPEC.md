# ROM Intake: Initial Candidate Profile

This document records the first locally inspected input for Stage 1. It is an intake profile only; the project does not execute the image as an emulator and has not yet decoded game assets.

## Inspected image

| Property | Observed value |
|---|---|
| User-supplied container | ZIP archive with one member |
| Member name | `Sonic & Knuckles + Sonic The Hedgehog 3 (World).md` |
| Uncompressed size | 4,194,304 bytes (4 MiB) |
| SHA-256 | `fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23` |
| SHA-1 | `cfbf98c36c776677290a872547ac47c53d2761d6` |
| MD5 | `c5b1c655c19f462ade0ac4e17a844d10` |
| Layout | Two consecutive 2 MiB images: Sonic & Knuckles first, Sonic 3 second |
| First header | `SEGA GENESIS`; title `SONIC & KNUCKLES`; product `GM MK-1563 -00`; region field `JUE` |
| Second header | `SEGA GENESIS`; title identifies `SONIC THE HEDGEHOG 3`; product `GM MK-1079 -00`; region field `U` |
| Profile ID | `sk-s3-lockon-4m-sha256-fba0677f` |

The header fields identify the candidate's stated product and region data. The hash identifies this exact byte image, not every possible dump or revision. No Sega checksum validation or revision equivalence is claimed. Other dumps must be analyzed before they are accepted as compatible.

## Intake behavior

- Accept a raw `.md` file or a ZIP containing exactly one non-directory `.md` member.
- Read from the selected path in memory. The inspector does not extract the archive or copy the source image.
- Require the 4 MiB size, the known SHA-256 fingerprint, and the two expected Genesis header locations/signatures/titles.
- Reject malformed ZIPs, ambiguous archives, wrong-size data, unexpected hashes, or mismatching headers with a specific error.
- Keep any future generated cache under Godot's per-user `user://` data directory, never under the checkout.
- Never store the user's original path in a generated manifest.

## Local cache manifest (planned)

The cache manifest will be JSON with a schema version, importer version, profile ID, source SHA-256, generated-resource index, and content hashes. It will not contain the source ROM, an absolute source path, or raw game data. Cache output stays local and is excluded from Git.

## Current feasibility boundary

The structural profile and local intake check are established. Asset extraction remains a separate feasibility task: identify public documentation or implement format readers for the specific graphics, palette, animation, and level structures needed by the original Godot runtime. The ROM is treated as input data; gameplay logic is implemented in this project.
