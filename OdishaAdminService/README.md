# Odisha Administrative Boundary Service

A Node.js microservice that determines the administrative hierarchy (District, Tehsil, Panchayat, Village) of a location in Odisha using coordinates.

## Tech Stack
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: PostgreSQL + PostGIS (Spatial Extension)
- **Caching**: node-cache

## Setup Instructions

### 1. Database Setup
Ensure you have PostgreSQL with PostGIS installed. Create a database and run the initialization script:

```bash
# Create the database
createdb mybhoomi_spatial

# Run the initialization script
psql -d mybhoomi_spatial -f init.sql
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Environment Configuration
Edit the `.env` file with your database credentials:
```env
PORT=3000
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_NAME=mybhoomi_spatial
DB_PORT=5432
CACHE_TTL=3600
```

### 4. Start the Service
```bash
npm start
```

## API Documentation

### Get Location Info
Returns administrative details for a specific latitude and longitude.

**Endpoint**: `GET /location-info`

**Parameters**:
- `lat`: Latitude (decimal)
- `lng`: Longitude (decimal)

**Example Request**:
`GET http://localhost:3000/location-info?lat=21.6231&lng=85.5839`

**Success Response (200 OK)**:
```json
{
  "district": "Keonjhar",
  "tehsil": "Keonjhar",
  "panchayat": "XXXX",
  "village": "Maidan Khel",
  "village_code": "123456"
}
```

**Error Responses**:
- `400 Bad Request`: Missing or invalid parameters.
- `404 Not Found`: Point is outside documented village boundaries.
- `500 Internal Server Error`: Database connection or query failure.

## Data Import Note
To populate the `villages` table with real boundary data, you can use `shp2pgsql` or standard GeoJSON import tools to insert polygons into the `geom` column. Ensure geometries are in `EPSG:4326` (WGS84).
