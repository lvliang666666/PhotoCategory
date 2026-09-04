# Android release signing

Release builds use the fixed keystore at
`android/keystore/photo-storer-release.keystore` through
`android/key.properties`.

Certificate SHA-256:
`24:8B:B8:48:73:32:91:93:D5:A9:40:CA:AB:CE:0E:83:05:8E:49:4C:61:AD:94:DE:0E:91:F0:23:13:8B:78:A4`

This certificate matches the historical APK produced on 2026-08-14. Do not
replace or regenerate the keystore. Losing it prevents future APKs from
updating installations signed with this identity. Keep an offline backup.
