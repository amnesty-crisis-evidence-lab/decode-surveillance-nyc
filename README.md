# Decode Surveillance - Data Processing
This repository covers the data processing part of Amnesty International's Decode Surveillance project. It accompanies the full methodology note.

## Requirements

The environment can be installed with [Miniforge/Mambaforge]. It should also run with Anaconda but this has not been test.

- Install [miniforge or mambaforge](https://github.com/conda-forge/miniforge).

- Create a conda environment named `amnesty_env`:
        ```
        conda env create -f environment.yml
        ```
        or, faster if you have installed [mamba] or are using [mambaforge](https://github.com/conda-forge/miniforge#mambaforge): 
        ```
        mamba env create -f environment.yml
        ```


## Jupyter Notebooks:
*(Described in the order of which each notebook should be run)*

### `process_full_data.ipynb`
- This notebook creates a single csv file, `counts_per_intersections.csv`, containing the appropriate information to allow for calculating the aggregate counts per intersection which would then be used as input for `aggregate_counts_over_intersections.ipynb`.

### `aggregate_counts_over_intersections.ipynb`
- This notebook uses information in `counts_per_intersections.csv` to calculate summary counts which are included in section `Finding summaries` of `Methodology Note Decode Surveillance`.

## Raw Data Files
*The following files are found in the `data` folder.* These CSV files contain the volunteers' results as extracted from the microtasking platform.

### `cameras.csv`: individual cameras tags

A Decoder (`DecoderID`) sees an Intersection (`IntersectionId`) and tags several cameras (each with an `Id` -- that's one row) and eventually press "Submits" which makes a submission (`SubmissionId`).

- Each row is the individual tag at camera seen by a decoder at an intersection with its location/type i.e. building or PTZ/Dome.

Columns:

- `DecoderId`: Assigned ID unique to the decoder.
- `IntersectionId`: Assigned ID unique to the intersection.
- `SubmissionId`: ID unique to the submission of this set of tags by this decoder at this intersection.
- `Type`: Type of public camera labelled by decoder, when the decoder believes the camera belongs to category: **street_light/traffic_signal/road_sign**. Empty otherwise.
- `Attached`: What is the camera attached to: **street_light/traffic_signal/road_sign** or **building** or **unknown**.
- `Createdtime`: Date and time the submission was created by the decoder.
- `Id`: Serial unique ID of this tag for this submission.
- `Title`: Full name of the camera label type along with what the location of the camera: **Dome or PTZ camera on traffic signal, streetlight or pole** or **Bullet camera on traffic signal, streetlight or pole** or **Camera on building**.
- The following columns describe the Point of View of the decoder within the  [Street View panorama](https://developers.google.com/maps/documentation/javascript/reference/street-view), i.e. where it is looking, in spherical coordinates:
    - `Pov.heading`: Camera heading in degrees relative to true north. True north is 0°, east is 90°, south is 180°, west is 270°.
    - `Pov.pitch`: Camera pitch in degrees, relative to the Street View vehicle. Ranges from 90° (directly upwards) to -90° (directly downwards).
    - `Pov.zoom`: Zoom level of the panorama. Fully zoomed-out is level 0, where the field of view is 180 degrees. Zooming in increases the zoom level.
- `Updatedtime`: Unknown, not used in the analysis.
- `DecoderGenericId`: Assigned numerical ID unique to the decoder, coherent accross projects. Bijective with `DecoderId`.


### `counts.csv`: counts of cameras per decoder per intersection
- Each row is the intersection seen by a specific decoder and the number of cameras for total/each type/attachment/ in this intersection.


Columns:

- `SubmissionId`: ID unique to the submission of the camera detected and labelled by the decoder at a specific intersection.
- `DecoderId`: Assigned ID unique to the decoder.
- `DecoderGenericId`: Assigned numerical ID unique to the decoder.
- `IntersectionId`: Assigned ID unique to the intersection.
- `StartTime`: Time the decoder started to look for cameras in a panorama of a specific intersection. 
- `EndTime`: Time the decoder exited the process of looking for cameras in a panorama of a specific intersection.
- `n_cameras`: Total number of cameras labelled by the decoder at an intersection.
- `attached_street`: Number of cameras labelled as attached to: street_light/traffic_signal/road_sign by the decoder at an intersection.
- `attached_building`: Number of cameras labelled as attached to: a building by the decoder at an intersection.
- `attached_unknown`: Number of cameras labelled by the decoder at an intersection where the decoder is unsure what the camera is attached to.
- `type_dome`: Number of cameras labelled as attached to: street_light/traffic_signal/road_sign and as type: dome by the decoder at an intersection.
- `type_bullet`: Number of cameras labelled as attached to: street_light/traffic_signal/road_sign and as type: bullet by the decoder at an intersection.
- `type_unknown`: Number of cameras labelled as attached to: street_light/traffic_signal/road_sign and where the type is unknown by the decoder at an intersection.

### `intersections.csv`: Metadata of the intersections
- Each row is the intersections over different areas of NY and its related info e.g.panorama id or whether there is a Traffic Signal present.

Columns:

- `IntersectionId`: Assigned ID unique to the intersection.
- `Url`: Internal URL for that intersection within the microtasking platform.
- `Borough`: Name of the borough of the specific intersection: **The Bronx** or **Manhattan** or **Brooklyn** or **Queens** or **Staten Island**.
- `TrafficSignal`: Indicates whether the specific intersection includes Traffic Lights. 
- `Lat`: WARNING: NOT the Latitude of the actual imagery. Latitude in degrees used **to request** a panorama from Street View, within [-90, 90]. This is only the latitude requested, not that of the actual imagery. For that, see `panorama_url.csv`'s `GoogleLat` column.
- `Long`: WARNING: NOT the Longitude of the actual imagery. Longitude in degrees used **to request** a panorama from Street View, within [-180, 180]. This is only the longitude requested, not that of the actual imagery. For that, see `panorama_url.csv`'s `GoogleLong` column.
- `PanoramaId`: ID of the intersection panorama (spherical image) in Street View. Used for any call to Street View API `panoid` argument.
- `ImageDate`: Date of photography of the Street View panorama.

### `panorama_url.csv`: Actual Latitudes and Longitudes of the panoramas returned by StreetView
- Each row is the PanoramaId along with its unique Latitude and Longitude as obtained from Google (*GoogleLat, GoogleLong*).

Columns:

- `PanoramaId`: ID of the intersection panorama (spherical image) in Street View. Used for any call to Street View API `panoid` argument.
- `Lat`: WARNING: NOT the Latitude of the actual imagery. Latitude in degrees used **to request** a panorama from Street View, within [-90, 90]. This is only the latitude requested, not that of the actual imagery. For that, see `GoogleLat` column.
- `Long`: WARNING: NOT the Longitude of the actual imagery. Longitude in degrees used **to request** a panorama from Street View, within [-180, 180]. This is only the longitude requested, not that of the actual imagery. For that, see `GoogleLong` column.
- `GoogleLat`: Latitude in degrees of the actual Street View panorama obtained from Google Street View API using the `PanoramaId`, within [-90, 90].
- `GoogleLong`: Longitude in degrees of the actual Street View panorama obtained from Google Street View API using the `PanoramaId`, within [-180, 180].

### `nyc_borough_boundary_water_query.json`
- Borough Boundaries (Water Areas Included) obtained from [NYC.gov Planning's Political and Administrative Districts webpage](https://www1.nyc.gov/site/planning/data-maps/open-data/districts-download-metadata.page), retrieved on 2021-12-20.
- Added in this repository for ease of reproduction.

## Aggregated data
*The following files are found in the `data` folder.* They contain the result of the aggregation of the volunteers' answers, for each intersection.


### `counts_per_intersections.csv`: Median of the decoders' counts for each type of camera for each intersection
- Contains aggregated counts over all intersections characterised by a unique `PanoramaId`.
- Generated in `aggregate_counts_over_intersections.ipynb`.

Columns:

- `PanoramaId`: ID unique to the Street View panorama of the intersection.
- The following columns describe the median number of cameras at the intersection according to the 3 decoders:
    - `n_cameras_median`: Total number of cameras.
    - `attached_street_median`: Number of cameras that is attached to a street_light/traffic_signal/road_sign.
    - `attached_building_median`: Number of cameras that is attached to a building.
    - `attached_unknown_median`: Number of cameras that is attached to an unknown location.
    - `type_dome_median`: Number of cameras of dome type.
    - `type_bullet_median`: Number of cameras of bullet type.
    - `type_unknown_median`: Number of cameras of unknown type.
- The following columns represent the level of agreement amongst the three decoders, this could be either: **Unanimous** or **2 vs 1** or **All disagree**:
    - `n_cameras_agreement`: Number of total cameras.
    - `attached_street_agreement`: Number of cameras attached to a street_light/traffic_signal/road_sign.
    - `attached_building_agreement`: Number of cameras attached to a building.
    - `attached_unknown_agreement`: Number of cameras of attached to an unknown location.
    - `type_dome_agreement`: Number of cameras of dome type.
    - `type_bullet_agreement`: Number of cameras of bullet type.
    - `type_unknown_agreement`: Number of cameras of unknown type.
- `Lat`: Latitude in degrees of the actual Street View panorama, from `panorama_url.csv`'s `GoogleLat`, within [-90, 90].
- `Long`: Longitude in degrees of the actual Street View panorama, from `panorama_url.csv`'s `GoogleLong`, within[-180, 180].
- `geometry_pano`: Point-geometry of the panorama for ease of plotting.
- `BoroName`: Name of the borough the specific intersection is found in, with respect to the query json from NYC.gov website.
- `URL`: URL of the Street View panorama.
- `ImageDate`: Date of photography of the Street View panorama.
