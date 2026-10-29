# ParkFinder

**Find the nearest parking — street, underground or open lot — with prices and reviews from real drivers.**

ParkFinder is a SwiftUI iPhone app with CarPlay support. It merges Apple Maps parking, the City of Toronto's Green P car parks, and spots added by the community, then layers live, crowd-sourced ratings and prices on top. When your drive ends, it notices you've parked, saves your car's location and asks a few quick questions so the information stays current for everyone.

Black-and-gold design throughout, including a dark, muted map with custom gold pins. Liquid Glass on iOS 26+, with a matching material fallback on iOS 17–18.

---

## Features

| Feature | Details |
| --- | --- |
| Nearest parking | A card at the bottom of the map always shows the closest spot matching your filter, with one-tap driving directions. |
| Street vs. underground vs. lot | Every spot is classified. Street spots use a square pin, lots and garages a round one. Filter chips switch between them. |
| Live prices | Drivers report what they paid per hour (or that it was free) and any time limit. The newest report is shown to everyone. |
| Reviews | 1–5 star ratings with comments. Averages appear on the map card, the detail sheet and in CarPlay. |
| Community corrections | If drivers say a spot is a different type than Apple Maps' guess, the majority answer wins. |
| Favourites | Star any spot. Favourites are marked on the map and listed on iPhone and CarPlay. |
| Parking detection | Detects the end of a drive from CarPlay disconnecting, Motion activity (driving → walking or stationary), and iOS location visits. A notification asks *Street, underground or open lot?* |
| Find my car | Your last parked location is pinned on the map with a "My Car" shortcut. |
| Add a spot | Add street parking anywhere. The address is filled in automatically. |
| CarPlay | Map of nearby spots, a nearest-first list, favourites, spot details, directions and save. |

## Requirements

- Xcode 27 or later
- iOS 17.0+ (Liquid Glass effects on iOS 26+)
- An Apple Developer account (for iCloud/CloudKit, and for CarPlay)

## Getting started

1. **Clone and open**

   ```sh
   git clone https://github.com/<your-username>/ParkFinder.git
   cd ParkFinder
   open ParkFinder.xcodeproj
   ```

2. **Signing.** Under *Signing & Capabilities*, select your own team. If you're forking, also change the bundle identifier (`OldMoneyCorp.ParkFinder`).

3. **iCloud container.** The app uses the CloudKit container `iCloud.OldMoneyCorp.ParkFinder`. If you change it, update it in two places:
   - `ParkFinder/ParkFinder.entitlements`
   - `ParkFinder/Community/CommunityService.swift` (`CKContainer(identifier:)`)

4. **CloudKit schema.** Run the app once and post a review so CloudKit creates the record types in the Development environment. Then, in the [CloudKit Console](https://icloud.developer.apple.com), add these indexes:

   | Record type | Field | Index |
   | --- | --- | --- |
   | `Review` | `spotID` | Queryable |
   | `CommunitySpot` | `location` | Queryable |

   Deploy the schema to Production before shipping.

5. **Run.** In the Simulator, set a location with **Features → Location → Custom Location** (for example `43.6487, -79.3854`, downtown Toronto). Otherwise the app has no GPS fix. To post reviews, sign in to iCloud in the Simulator's Settings app.

## CarPlay

The CarPlay interface lives in `ParkFinder/CarPlay/CarPlaySceneDelegate.swift`. It needs the **CarPlay Parking** entitlement, which Apple must approve:

1. Request it at [developer.apple.com/carplay](https://developer.apple.com/carplay/).
2. Once approved, add `com.apple.developer.carplay-parking` (Boolean `YES`) to `ParkFinder.entitlements` and regenerate your provisioning profile.
3. Test with **I/O → External Displays → CarPlay** in the Simulator.

The entitlement isn't included in the repo, because builds fail to sign without Apple's approval.

## Parking detection

Parking detection is opt-in, from the map banner or Settings. It uses:

- **Location: Always.** Visit monitoring and significant-change monitoring wake the app when a drive starts or ends, even if the app was closed. Precise background GPS runs only while driving.
- **Motion & Fitness.** Tells driving apart from walking or standing still.
- **Notifications.** Asks about the spot, with quick-pick buttons for the parking type.

Detection can't be simulated, so test it on a real iPhone.

## Project structure

```
ParkFinder/
├── App/            App entry, AppDelegate (CarPlay scene routing), shared AppModel
├── CarPlay/        CarPlay templates
├── Community/      CloudKit public-database service (reviews, prices, community spots)
├── Components/     Reusable views: stars, badges, pickers, price fields
├── Favorites/      Favourites store (on-device JSON) and list
├── Map/            Main map screen, pins, filters, nearest-spot card
├── Models/         ParkingSpot, ParkingKind, SpotReview, SpotSummary, …
├── Parking/        Parking detection, notifications, post-parking questions
├── Search/         Location, Apple Maps search, Green P feed, ParkingRepository
├── Settings/       Detection toggle, saved car, data credits
├── SpotDetail/     Spot detail sheet and review form
└── Theme/          Black & gold palette, glass panel, gold button style
```

`ParkingRepository` is the single source of truth for nearby spots. The SwiftUI views and the CarPlay scene share it through `AppModel.shared`.

## Data sources

- **Apple Maps:** parking points of interest via `MKLocalPointsOfInterestRequest`.
- **Green P Parking, City of Toronto:** garage and surface-lot locations, capacities and posted rates. Contains information licensed under the [Open Government Licence – Toronto](https://open.toronto.ca/open-data-license/). The published dataset dates from 2019, so posted rates may be out of date, and driver-reported prices take priority.
- **ParkFinder drivers:** street parking, prices, time limits and reviews, stored in the CloudKit public database.

Toronto doesn't publish on-street meter locations as open data, so street parking comes entirely from the community.

## Privacy

- Favourites and your parked-car location stay on your device.
- Reviews, prices and added spots are public. They're stored in CloudKit and tied to your iCloud account's anonymous record ID, not your name or email.
- Location is used only to find parking and detect when you've parked.

## Roadmap

- [ ] Parking-meter expiry reminders based on reported time limits
- [ ] Reporting and moderation of incorrect spots and reviews
- [ ] More city open-data feeds
- [ ] Widgets and Live Activity for the active parking session
- [ ] Unit tests (Swift Testing) for `SpotSummary`, `ParkingKind.guess` and repository merging

## License

No license has been chosen yet. Until one is added, all rights are reserved.
