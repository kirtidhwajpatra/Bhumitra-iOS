# Bhumitra 🌍 (formerly MyBhoomi)

[![App Store](https://img.shields.io/badge/App_Store-Download-blue?logo=apple&logoColor=white)](https://apps.apple.com/in/app/bhumitra/id6760656162)

**Bhumitra** is a high-performance Land Records and Geospatial Information System (GIS) application custom-tailored for Odisha, India. It bridges the gap between traditional textual land registry records (Bhulekh) and modern interactive geospatial maps, letting users instantly visualize property boundaries and access verified ownership details on the ground.

---

## 🎯 Our Motif & Vision

In India, land ownership records are historically paper-based or stored in tabular database systems (like the official Bhulekh registry). For everyday land owners, buyers, and agricultural administrators, it is extremely difficult to correlate a textual plot number (e.g., "Plot 185") with its actual boundaries, coordinates, and physical shape on a satellite map.

**Bhumitra** was created to solve this opacity. Our motif is to:
- **Democratize Land Data**: Bring complex cadastral survey maps directly to a user's mobile device.
- **Enable Ground-Truth Verification**: Let users walk a boundary on-site and verify if it matches official government plot maps using real-time GPS tracking.
- **Unify GIS and Registry**: Combine high-speed offline map tiling (PMTiles) with real-time web scraping to load ownership details (Record of Rights - RoR) in a single tap.

---

## 🏗 Project Architecture & Tech Stack

Bhumitra is built using a decoupled, high-performance architecture split into a native iOS client and a containerized Python backend.

### 1. iOS Mobile Client (`Bhumitra`)
Designed with **Clean Architecture** principles and **Domain-Driven Design (DDD)**:
- **Presentation Layer**: Built completely in **SwiftUI** using modern design principles (glassmorphism, micro-interactions, spring animations, and native haptic feedback).
- **Domain Layer**: Contains pure business logic and model definitions (e.g., `Parcel`, `Coordinate`, and Repository Protocols).
- **Data Layer**: Manages local persistence, network service wrappers, and coordinates the local/remote map tile loading.
- **GIS Mapping Engine**: Integrates **MapLibre Native** and **MapLibre SwiftUI** to stream vector data containing over 1.2GB of cadastral geometry.

### 2. Scraper & API Backend (`BhulekBackend`)
An asynchronous web scraping service that communicates with the official Odisha Bhulekh portal:
- **Framework**: **FastAPI** + **Uvicorn** for maximum speed and concurrency.
- **Scraping Engine**: **Playwright** (headless Chromium) combined with **BeautifulSoup4** to bypass legacy ASPX viewstates and extract land details in real-time.
- **Deployment**: Fully dockerized for seamless deployment on Google Cloud Run or AWS.

---

## 📱 Screens & User Journey Flow

### 🎬 1. App Launch & Splash Screen
- On launch, the app initiates a smooth splash transition, showing the Bhumitra logo with a spring scale animation.
- A background map blur fades away as the GIS engine initializes the vector layers.

### 🗺 2. The Interactive GIS Map (`MainView`)
- Displays high-resolution satellite imagery layered with vector plot lines.
- **Zoom Controls**: Integrated scale-level trackers. Plot outlines are configured to fade in dynamically at zoom levels **14.5+** and labels at **15.5+** to prevent UI clutter.
- **Interactive Controls**: Toggle between satellite and hybrid vector modes, locate/track the user's location, and toggle cadastral boundary visibility.

### 🔍 3. Unified Search Bar (`SearchBarView`)
- Supports autocomplete suggestions for:
  - **Plots** (e.g., searching "185" suggests plot zones in the current region).
  - **Local Villages / Towns** (pre-loaded list of Keonjhar subregions).
  - **Global Places** (integrated via Apple MapKit local search).

### 📄 4. Land Parcel Detail Sheet (`ParcelDetailSheet`)
- Tapping any defined plot boundary on the map triggers this bottom drawer.
- Displays comprehensive geographical data (Village, District, Tahasil, Local Body).
- **View Ownership Record**: Tapping this fetches the official Record of Rights (RoR) data from the backend. The scraper retrieves:
  - Khatiyan Holders / Owners & their respective shares.
  - Land classification type (Kisama).
  - Area in acres.
- **Download Official RoR**: One-tap action to fetch and generate the official PDF, allowing native sharing and saving.

### 📍 5. Generic Location Sheet (`LocationDetailSheet`)
- Tapping on a non-demarcated coordinate on the map displays the latitude/longitude, calculates administrative boundaries, and guides the user to select an outlined plot.

### 💼 6. Digital Services Menu (`QuickFeaturesSheet`)
Accessible settings and offline utilities:
- **Offline Maps**: Allows downloading specific district/block boundary datasets to navigate without internet connectivity.
- **Manual RoR Search**: Form-based navigation (Select District ➔ Select Tahasil ➔ Select Village ➔ Search by Khata/Plot/Tenant) matching the official Bhulekh hierarchy.
- **Downloaded RoRs Archive**: A local historical log of previously downloaded PDFs, accessible completely offline.

---

## 🚀 Getting Started for Developers

### Prerequisites
- macOS with Xcode 16.0+ installed.
- iOS Simulator or physical testing device.
- Python 3.12+ (for backend development).

### iOS App Configuration & Data Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/kirtidhwajpatra/MyBhoomi.git
   cd MyBhoomi
   ```
2. **Install Dependencies**:
   - Open `MyBhoomi.xcodeproj` in Xcode.
   - Xcode will automatically resolve the Swift Package dependencies:
     - **MapLibre Native** (version `6.24.0`+)
     - **MapLibre SwiftUI**
3. **Configure Local GIS Data**:
   - For simulator development, copy the full Odisha map dataset `Odisha4kgeo_OD_Cadastrals-part0000.pmtiles` (1.3 GB) to your Mac's `~/Downloads` directory.
   - The app's `AppConfig` will automatically detect this path in development, bypassing remote Cloud Storage.
   - If the file is not in your downloads, the app will fall back to using the bundled regional `Keonjhar_Cadastrals.pmtiles` resource.
4. **Build & Run**:
   - Target an iOS Simulator (e.g., iPhone 16/17 Pro).
   - Run via Xcode (`Cmd + R`) or build using the command line:
     ```bash
     xcodebuild -project MyBhoomi.xcodeproj -scheme MyBhoomi -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" -skipMacroValidation clean build
     ```

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd BhulekBackend
   ```
2. Install Python requirements & Playwright:
   ```bash
   pip install -r requirements.txt
   playwright install chromium
   ```
3. Run the FastAPI development server:
   ```bash
   python main.py
   ```
   The API will be available locally at `http://127.0.0.1:8000`.

---

## 📄 License & Disclaimer

Bhumitra is developed for private convenience. All data retrieved from the official Bhulekh portal remains the property of the respective government revenue departments. Users must consult certified land offices for official and legally binding records.
