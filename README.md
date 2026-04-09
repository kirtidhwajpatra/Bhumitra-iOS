# MyBhoomi 🌍

**MyBhoomi** is a comprehensive Land Records and Geospatial Information System (GIS) designed specifically for Odisha, India. It bridges the gap between traditional land records (Bhulekh) and modern map-based visualization, providing users with a seamless experience to explore cadastral plots and access Record of Rights (RoR) data.

---

## 🏗 Project Architecture

The project consists of two primary components:

1.  **MyBhoomi (iOS App)**: A high-performance mobile application built with SwiftUI and MapLibre, capable of rendering massive cadastral datasets (1.2GB+) using vector tiles and PMTiles technology.
2.  **Bhulekh Backend**: A robust FastAPI-based service that handles data extraction, translation, and enrichment from the official Odisha Bhulekh portal using Playwright and BeautifulSoup.

---

## 📱 MyBhoomi - iOS Application

The iOS application provides a premium map interface for interacting with land parcels.

### Key Features
- 🗺 **Cadastral GIS Engine**: Native vector rendering for high-performance plot visualization.
- 📂 **PMTiles Support**: Streaming of Cadastral plots directly from local containers using `MLNVectorTileSource`.
- ✨ **Clean Architecture**: Implementation of Domain-Driven Design (DDD) with decoupled Presentation, Domain, and Data layers.
- 📍 **Parcel Identification**: One-tap access to plot details directly from the map.

### Tech Stack
- **Language**: Swift
- **Framework**: SwiftUI
- **GIS**: MapLibre Native, PMTiles
- **Build System**: CocoaPods & Swift Package Manager

---

## ⚙️ Bhulekh Backend

The backend service serves as the data powerhouse, fetching and processing land records in real-time.

### Key Features
- 🚀 **Asynchronous API**: Built with FastAPI for high concurrency and performance.
- 🕵️ **Web Scrapers**: Sophisticated scrapers using Playwright and BeautifulSoup to interface with the Bhulekh portal.
- 🌐 **Translation Engine**: On-the-fly translation of land record details using `deep-translator`.
- 🐳 **Dockerized**: Fully containerized for easy deployment to Google Cloud Run or AWS.

### Tech Stack
- **Language**: Python 3.12+
- **Web Framework**: FastAPI, Uvicorn
- **Scraping**: Playwright, BeautifulSoup4
- **Containerization**: Docker

---

## 🚀 Getting Started

### iOS App Setup
1. Open `MyBhoomi.xcodeproj` in Xcode.
2. Install dependencies via SPM:
   - **MapLibre Native**
   - **MapLibre SwiftUI**
3. Ensure the required `.pmtiles` dataset is available in your designated data folder.
4. Run on a simulator or physical device.

### Backend Setup
1. Navigate to the `BhulekBackend` directory.
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   playwright install chromium
   ```
3. Run the development server:
   ```bash
   python main.py
   ```

---

## 📄 License

This project is developed for private use. All data sourced from Bhulekh Odisha remains the property of the respective government departments.

---

*Developed by [Kirtidhwaj Patra](https://github.com/kirtidhwajpatra)*
