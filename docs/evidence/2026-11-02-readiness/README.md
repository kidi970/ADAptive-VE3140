# Evidens fra programvaregjennomgangen 2. november 2026

Alle kontroller her er utført uten USB-/GPIO-/debugtilgang til bilen.
Ingen reset, flashing, LED-observasjon eller motorkjøring er utført.

- `verification.json`: kommandoer, returkoder, 2599 Ada-kontrollpunkter,
  kildehash og LaTeX-kildehash fra bestått full kontroll.
- `ada-tests.log`: ti beståtte Ada-suiter med faktisk applikasjonskode.
- `python-tests.log`: 40 beståtte tester.
- `mutations.log`: fem kompilerbare kildemutasjoner avvist av assertions
  og én avvist SPARK-kontraktmutasjon, bare i midlertidige kopier.
- `proof.log` / `spark-summary.txt`: én produksjonsenhet, fire samlede
  analysekontroller uten ubeviste kontroller. Ikke helbil- eller tidsbevis.
- `*-build.log`: ARM-bygg og lokale dokumentbygg. Et program som er
  «up to date» er verifisert av byggeverktøyets avhengigheter.
- `firmware-files.json`: SHA-256/størrelse for lokale artefakter; alle
  har `flashed_in_this_review: false`.
- `report-sources.log`: 45 byteidentiske kilde-/konfigurasjonskopier.

Fysiske data fra tidligere økter har egne mapper med sine opprinnelige
firmwarehash. De er ikke kjørt på nytt her. Se hovedloggen
`../../ADAptive-kodekontroll-2026-11-02.md` og akseptanseplanen.
