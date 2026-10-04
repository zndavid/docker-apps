# HDR preference and Dolby Vision rejection

The original DV-only regex looked for HDR only **after** the DV token. That made
`Movie.DV.HDR10` and `Movie.HDR10.DV` behave differently. The updated pattern
checks the entire title for an HDR token before detecting DV, regardless of order.
It also handles underscore separators without matching `DVD`, `HDRip` or `HDR100`
as the intended tokens. SDR/HLG guards use the same separator handling.
The HDR-present condition is now required: the old optional condition could
allow the positive format to match a plain non-HDR title when the negated
required conditions matched. A plain 1080p title now earns no HDR preference.

## Import and score in Radarr

These JSON files are importable Custom Formats, not complete Quality Profiles.
A Git/Compose deployment does not import them into Radarr automatically.

1. Open **Settings -> Custom Formats**, edit the existing format named
   `Prefer HDR, Allow DV+HDR, Exclude DV-only`, and import/replace its definition
   with `radarr_custom_format.json`. Retaining its name helps avoid duplicate
   preference formats; keep its existing ID/profile assignments where possible.
2. Import `radarr_dv_only_custom_format.json` as a second format.
3. In **Settings -> Profiles**, apply scores to every relevant Quality Profile:

   | Custom Format / setting | Example score |
   | --- | --- |
   | Existing HDR preference format | `+100` (or retain your positive preference) |
   | `DV-only (no HDR fallback)` | `-10000` |
   | Minimum Custom Format Score | `0` |

   The rejection magnitude must exceed the total possible positive scores from
   other formats. If your profile can offset `-10000`, use a larger negative
   penalty or adjust the scoring so DV-only titles stay below the minimum.
4. Use Radarr's parsing/test view to verify both HDR/DV orders and a DV-only
   title before triggering searches. Keep existing qualities, language rules,
   upgrade settings and other format scores unless you intend to change them.

A negated condition in the positive HDR format merely prevents that **format**
from matching; it does not itself block a release. The separate negative format
and minimum score enforce the requested exclusion. The old format name is kept
for compatibility, while the actual rejection is assigned to the second format.

| Release title | HDR preference | DV-only penalty |
| --- | --- | --- |
| `Movie.DV.HDR10` | Matches | No |
| `Movie.HDR10.DV` | Matches | No |
| `Movie_HDR10_DoVi` | Matches | No |
| `Movie.DV.2160p` | No | Matches |
| `Movie.HDR10.2160p` | Matches | No |
| `Movie.SDR.1080p` | No | No |

These are title-metadata rules; they cannot establish the real video stream's
HDR fallback capabilities if the release is mislabeled. The regression tests
cover order, tokens and separators without adding Profilarr or Recyclarr.

[Reference: Radarr profile scores](https://trash-guides.info/Radarr/radarr-setup-quality-profiles/)
