# Tip jar ("Support Stamped!")

Three consumable in-app purchases. They are a thank-you only and unlock nothing.
iPhone, iPad, Mac and Vision Pro share one App Store record and one bundle ID,
so the same three products work on every platform.

| Product ID | Reference name | Price (US) |
|---|---|---|
| `name.GeorgeClinkscales.Stamped.tip.small` | Small Tip | $0.99 |
| `name.GeorgeClinkscales.Stamped.tip.medium` | Medium Tip | $2.99 |
| `name.GeorgeClinkscales.Stamped.tip.large` | Large Tip | $4.99 |

Prices in the app always come from the App Store (`Product.displayPrice`), so they show
in each buyer's currency. Until the products exist in App Store Connect, the app shows
"Tips aren't available right now".

## Where it is in the app

- **iPhone:** Settings → Support Stamped! (its own section, above Reset).
- **iPad and Mac:** Settings sidebar → Support Stamped! (opens in the detail pane).
- **Vision Pro:** the heart button in the city list's toolbar opens it as a sheet.

## Code

- `Stamped! A City Passport/Managers/TipJarStore.swift`: loads, buys, verifies and
  finishes; listens to `Transaction.updates` from app launch (both app `init()`s).
- `Stamped! A City Passport/SettingsView/TipJarView.swift`: the screen.
- Both files are shared with the Tally-AVP target (membership exceptions in the project).
- `StampedTests/TipJarTests.swift`: IDs, sorting, and a test purchase in a local
  StoreKit session.

## Local testing (no App Store Connect needed)

`StampedTests/TipJar.storekit` lists the three products. Both shared schemes
("Stamped! A City Passport" and "Tally-AVP") use it under **Run → Options → StoreKit
Configuration**, so pressing Run in Xcode shows fake tips with a test payment sheet.
It only applies to Run from Xcode: Archive, TestFlight and App Store builds never use it.
See test purchases in Xcode with **Debug → StoreKit → Manage Transactions**.

To test against the real (sandbox) App Store instead, set StoreKit Configuration to
None in the scheme, or use a TestFlight build.

`TipJarTests` buys tips in a local `SKTestSession`. Run them on one simulator with
parallel testing off (`-parallel-testing-enabled NO`): on Xcode's cloned parallel
simulators the test session sometimes returns no products and the purchase tests fail.

---

## Checklist for George (App Store Connect)

### 1. Agreements, banking and tax

- [ ] App Store Connect → **Business**: the **Paid Applications** agreement is
      **Active** (not "Pending" or "New"). In-app purchases won't load without it.
- [ ] Banking information is filled in and active.
- [ ] Tax forms (US W-9 or W-8) are complete.

### 2. Create the three consumables

App Store Connect → Apps → Stamped! → **Monetization → In-App Purchases** → (+).
For each one:

- [ ] Type: **Consumable**
- [ ] Reference name and Product ID exactly as in the table at the top
      (product IDs can never be changed or reused once created)
- [ ] Availability: all countries/regions
- [ ] Price: $0.99, $2.99, $4.99 (US base price; let Apple set the other countries)
- [ ] App Store localizations: add all 10 languages below. Display name max 30
      characters, description max 45 (all texts below fit).

#### Display names and descriptions, ready to paste

**English (U.S.) — en-US**
| Product | Display name | Description |
|---|---|---|
| small | Small Tip | A small thank-you to the developer |
| medium | Medium Tip | A medium thank-you to the developer |
| large | Large Tip | A big thank-you to the developer |

**German — de-DE**
| Product | Display name | Description |
|---|---|---|
| small | Kleines Trinkgeld | Ein kleines Dankeschön an den Entwickler |
| medium | Mittleres Trinkgeld | Ein mittleres Dankeschön an den Entwickler |
| large | Großes Trinkgeld | Ein großes Dankeschön an den Entwickler |

**Spanish (Spain) — es-ES**
| Product | Display name | Description |
|---|---|---|
| small | Propina pequeña | Un pequeño agradecimiento al desarrollador |
| medium | Propina mediana | Un agradecimiento mediano al desarrollador |
| large | Propina grande | Un gran agradecimiento al desarrollador |

**Spanish (Mexico) — es-MX**
| Product | Display name | Description |
|---|---|---|
| small | Propina pequeña | Un pequeño agradecimiento al desarrollador |
| medium | Propina mediana | Un agradecimiento mediano al desarrollador |
| large | Propina grande | Un gran agradecimiento al desarrollador |

**French — fr-FR**
| Product | Display name | Description |
|---|---|---|
| small | Petit pourboire | Un petit merci au développeur |
| medium | Pourboire moyen | Un beau merci au développeur |
| large | Gros pourboire | Un grand merci au développeur |

**Italian — it**
| Product | Display name | Description |
|---|---|---|
| small | Mancia piccola | Un piccolo grazie allo sviluppatore |
| medium | Mancia media | Un grazie di cuore allo sviluppatore |
| large | Mancia grande | Un grande grazie allo sviluppatore |

**Japanese — ja**
| Product | Display name | Description |
|---|---|---|
| small | 小さなチップ | 開発者へのささやかな感謝 |
| medium | 中くらいのチップ | 開発者への感謝の気持ち |
| large | 大きなチップ | 開発者への大きな感謝 |

**Korean — ko**
| Product | Display name | Description |
|---|---|---|
| small | 작은 팁 | 개발자에게 보내는 작은 감사 |
| medium | 중간 팁 | 개발자에게 보내는 감사 |
| large | 큰 팁 | 개발자에게 보내는 큰 감사 |

**Portuguese (Brazil) — pt-BR**
| Product | Display name | Description |
|---|---|---|
| small | Gorjeta pequena | Um pequeno agradecimento ao desenvolvedor |
| medium | Gorjeta média | Um agradecimento médio ao desenvolvedor |
| large | Gorjeta grande | Um grande agradecimento ao desenvolvedor |

**Chinese (Simplified) — zh-Hans**
| Product | Display name | Description |
|---|---|---|
| small | 小额打赏 | 给开发者的一点心意 |
| medium | 中额打赏 | 给开发者的一份心意 |
| large | 大额打赏 | 给开发者的一份大大的感谢 |

### 3. Review information (each product)

- [ ] **Review screenshot**: a screenshot of the Support Stamped! screen on iPhone
      (Settings → Support Stamped!). One screenshot can be reused for all three.
      A simulator screenshot at full iPhone size is fine.
- [ ] Review notes (optional), for example: "Optional tip. It unlocks no content or
      features. Open Settings → Support Stamped! on iPhone/iPad/Mac, or the heart
      button in the city list on Vision Pro."
- [ ] Each product should now show **Ready to Submit**.

### 4. Submit with version 2.9

The first in-app purchases must be submitted together with a new app version.

- [ ] Open the 2.9 version page (iOS; also macOS and visionOS if submitting those).
- [ ] In **In-App Purchases and Subscriptions**, click (+) and select all three tips.
- [ ] Submit 2.9 for review as usual.
- [ ] After approval, buy a real tip once on your own device to confirm it works.
