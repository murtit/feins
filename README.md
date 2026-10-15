# Feins – „Was gits feins?“

<img src="Feins/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" align="right" alt="App-Icon: handgezeichneter Smiley, der die Zunge rausstreckt">

Simple iOS-App, mit der man Gerichte, die einem im Alltag einfallen, abspeichern kann. Die App erinnert dann am Mittag- oder Abendessen, dass man doch das kochen könnte.

## Funktionen

- **Gericht festhalten**, so einfach wie möglich: auf den runden Knopf unten rechts tippen und eintippen, oder den Knopf nach oben ziehen und einsprechen (Spracherkennung auf dem iPhone, Schweizer Hochdeutsch).
- **Automatisch verfeinert:** Tipp- und Erkennungsfehler werden korrigiert, das Gericht wird kategorisiert und mit einem Rezept (Zutaten, Schritte, Dauer) ergänzt.
  - Mit Claude-API-Schlüssel: Claude (`claude-opus-5-5`) übernimmt das.
  - Ohne Schlüssel: Offline-Modus erkennt rund 30 bekannte Gerichte auch mit Tippfehlern und ordnet über Schlüsselwörter ein.
- **Random Chooser „Was gits feins?“:** würfelt ein Gericht: Ein 3D-Würfel springt, überschlägt sich und landet, dann kommt der Vorschlag. Antippen von Würfel oder Knopf genügt.
  - Quelle wählbar: *Nur meine* oder *Auch neue Ideen* (eingebauter Katalog, mit Schlüssel zusätzlich frische Ideen von Claude).
  - Optional Zutaten angeben: Es kommen nur Gerichte, die diese Zutaten verwenden.
- **Erinnerungen** zum Mittag- und Abendessen mit einem Vorschlag aus den eigenen Gerichten.
- **Design:** warmes Papier, Tinte und ein einziger Akzent (Paprika). Hell, Dunkel oder Automatisch.

## Entwickeln

Voraussetzung: Xcode 26 oder neuer.

1. `Feins.xcodeproj` öffnen (oder `make open`).
2. Oben das Schema **Feins** und einen Simulator wie **iPhone 17 Pro** wählen, dann ▶︎ (⌘R).
3. Für ein eigenes iPhone: Target **Feins** → *Signing & Capabilities* → eigenes **Team** wählen.

```bash
make test     # Unit- und UI-Tests im Simulator
```

Das Projekt wird aus `project.yml` mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) erzeugt und ist eingecheckt. Wer `project.yml` ändert, kann `brew install xcodegen && make project` ausführen; auf Pull Requests generiert und committet der Workflow *Xcode-Projekt* das Projekt sonst automatisch.

**Claude API lokal nutzen:** in der App unter *Einstellungen → Claude (KI)* den Schlüssel eintragen (wird im Schlüsselbund gespeichert), oder beim Entwickeln im Xcode-Schema die Umgebungsvariable `ANTHROPIC_API_KEY` setzen.

### Aufbau

| Ordner | Inhalt |
| --- | --- |
| `Feins/App` | Einstieg, App-Zustand, Startargumente für Tests |
| `Feins/Models` | SwiftData-Modell `Dish`, Kategorien, Entwürfe/Ideen |
| `Feins/Services` | Claude-Anbindung, Offline-Assistent, Random-Chooser-Logik, Spracheingabe, Erinnerungen |
| `Feins/Views` | SwiftUI-Screens |
| `Feins/Design` | Farben, Schriften, Smiley |
| `FeinsTests` | Unit-Tests (Swift Testing) |
| `FeinsUITests` | UI-Tests, erzeugen auch die Screenshots |
| `scripts/` | CI-Hilfsskripte, Icon-Generator |

## CI/CD

| Workflow | Wann | Was |
| --- | --- | --- |
| `CI` | Jede PR und jeder Push auf `main` | Startet einen macOS-Runner mit dem neuesten Xcode, bootet einen iPhone-Simulator, führt Unit- und UI-Tests aus, exportiert die Screenshots und postet sie (hell/dunkel) als Kommentar in die PR. Die Bilder liegen auf dem Branch `ci-screenshots`. |
| `Xcode-Projekt` | Jede PR und jeder Push auf `main` | Generiert `Feins.xcodeproj` aus `project.yml`. Auf PRs wird ein verändertes Projekt automatisch auf den Branch committet, auf `main` schlägt der Check bei einem veralteten Projekt fehl. |
| `TestFlight` | Manuell oder Tag `v*` | Archiviert, signiert (automatisch via App Store Connect API) und lädt die App zu TestFlight hoch. |

### Secrets (Settings → Secrets and variables → Actions)

| Secret | Pflicht | Wofür |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | optional | Aktiviert in der CI einen Live-Test gegen die echte Claude API. |
| `APPLE_TEAM_ID` | für TestFlight | 10-stellige Team-ID aus dem Apple Developer Account. |
| `ASC_KEY_ID` | für TestFlight | Key-ID eines App Store Connect API-Schlüssels (Rolle *Admin*, wegen Cloud-Signing). |
| `ASC_ISSUER_ID` | für TestFlight | Issuer-ID von derselben Seite in App Store Connect. |
| `ASC_KEY_P8_BASE64` | für TestFlight | Inhalt der `.p8`-Datei, Base64-kodiert: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

### Auslieferung via TestFlight

1. In App Store Connect eine App mit der Bundle-ID `ch.murtit.feins` anlegen.
2. Die vier Secrets oben setzen.
3. Unter *Actions → TestFlight → Run workflow* starten oder einen Tag pushen (`git tag v0.1.0 && git push --tags`).

Fehlen Secrets, wird der Workflow mit einem Hinweis übersprungen statt rot zu werden.

### Hinweis zu iOS 27

GitHubs macOS-Runner haben aktuell höchstens Xcode 26.6 mit dem iOS-26.5-SDK. Deshalb ist das Deployment-Target iOS 26.0. Die CI nimmt automatisch das neueste installierte Xcode; sobald Xcode 27 auf den Runnern ist, genügt es, in `project.yml` `deploymentTarget` auf `"27.0"` zu setzen.
