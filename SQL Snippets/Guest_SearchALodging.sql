DELIMITER //

CREATE PROCEDURE Guest_SearchALodging(
    IN category VARCHAR(64),
    IN capacity INT,
    IN city VARCHAR(128)
)

BEGIN

    -- Query all lodgings corresponding to the searched category
    SELECT lodging.Description AS "Lodging", lodging.Category, lodging.Capacity, location.Street, city.Name AS "City"
    FROM lodging
    INNER JOIN location ON lodging.LocationID = location.ID
    INNER JOIN city ON location.CityID = city.ID
    INNER JOIN state ON location.StateID = state.ID
    INNER JOIN country ON location.CountryID = country.ID
    INNER JOIN continent ON location.ContinentID = continent.ID
    WHERE lodging.Category = category

    EXCEPT
    -- Filter out all results that do not fit the capacity criteria
    SELECT lodging.Description AS "Lodging", lodging.Category, lodging.Capacity, location.Street, city.Name AS "City"
    FROM lodging
    INNER JOIN location ON lodging.LocationID = location.ID
    INNER JOIN city ON location.CityID = city.ID
    INNER JOIN state ON location.StateID = state.ID
    INNER JOIN country ON location.CountryID = country.ID
    INNER JOIN continent ON location.ContinentID = continent.ID
    WHERE lodging.Capacity < capacity

    EXCEPT
    -- Filter out all results that do not fit the city criteria
    SELECT lodging.Description AS "Lodging", lodging.Category, lodging.Capacity, location.Street, city.Name AS "City"
    FROM lodging
    INNER JOIN location ON lodging.LocationID = location.ID
    INNER JOIN city ON location.CityID = city.ID
    INNER JOIN state ON location.StateID = state.ID
    INNER JOIN country ON location.CountryID = country.ID
    INNER JOIN continent ON location.ContinentID = continent.ID
    WHERE city.Name <> city;

END //