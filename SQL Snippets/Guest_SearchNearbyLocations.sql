DELIMITER //

CREATE PROCEDURE Guest_SearchNearbyLocations(
    IN lodging VARCHAR(128),
    IN distance DECIMAL(4,1),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE lodging_latitude DECIMAL(17,14);
    DECLARE lodging_longitude DECIMAL(17,14);
    DECLARE lodging_city INT;
    DECLARE earth_radius DECIMAL(7,0);

    -- Check if the lodging exists
    IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

        -- Set the Earth Radius in m
        SET earth_radius = 6371;

        -- Query the coordinates of the lodging
        SELECT location.Longitude, location.Latitude INTO lodging_longitude, lodging_latitude
        FROM location
        INNER JOIN lodging ON lodging.LocationID = location.ID
        WHERE lodging.Description = lodging;

        -- Query the city ID of the lodging
        SELECT location.CityID INTO lodging_city FROM location 
        INNER JOIN lodging ON lodging.LocationID = location.ID WHERE lodging.Description = lodging;

        -- Search for sights in the given distance with a maximum distance of the city boundaries (Location must be in the same city)
        SELECT sight.Name, location.Street,
        ROUND(earth_radius * SQRT(POWER((RADIANS(location.Longitude) - RADIANS(lodging_longitude)) * COS(0.5 *(RADIANS(location.Latitude) + RADIANS(lodging_latitude))), 2)
        + POWER(RADIANS(location.Latitude) - RADIANS(lodging_latitude), 2)),1) AS "Distance (km)" 
        FROM sight INNER JOIN location ON location.ID = sight.LocationID WHERE location.CityID = lodging_city AND 
        (earth_radius * SQRT(POWER((RADIANS(location.Longitude) - RADIANS(lodging_longitude)) * COS(0.5 *(RADIANS(location.Latitude) + RADIANS(lodging_latitude))), 2)
        + POWER(RADIANS(location.Latitude) - RADIANS(lodging_latitude), 2))) < distance;

        -- Search for public transport in the given distance with a maximum distance of the city boundaries (Location must be in the same city)
        SELECT publictransport.Description, location.Street,
        ROUND(earth_radius * SQRT(POWER((RADIANS(location.Longitude) - RADIANS(lodging_longitude)) * COS(0.5 *(RADIANS(location.Latitude) + RADIANS(lodging_latitude))), 2)
        + POWER(RADIANS(location.Latitude) - RADIANS(lodging_latitude), 2)),1) AS "Distance (km)" 
        FROM publictransport INNER JOIN location ON location.ID = publictransport.LocationID WHERE location.CityID = lodging_city AND 
        (earth_radius * SQRT(POWER((RADIANS(location.Longitude) - RADIANS(lodging_longitude)) * COS(0.5 *(RADIANS(location.Latitude) + RADIANS(lodging_latitude))), 2)
        + POWER(RADIANS(location.Latitude) - RADIANS(lodging_latitude), 2))) < distance; 

        -- Return an message
        SET message = "Results";

    -- Lodging does not exist
    ELSE
        SET message = "Search Failed - Lodging Not Found";
    END IF;
END //
