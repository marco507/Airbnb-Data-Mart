DELIMITER //

CREATE PROCEDURE Guest_SearchGeographically(
    IN city VARCHAR(128),
    IN state VARCHAR(128),
    IN country VARCHAR(64),
    IN continent VARCHAR(16)
)

BEGIN

    -- Search by continent
    IF continent IN (SELECT continent.Name FROM continent) AND (city = "" AND state = "" AND country = "") THEN
    
        -- Query all lodgings from the given continent
        SELECT lodging.Description AS "Lodging", location.Street, city.Name AS "City", state.Name AS "State", country.Name AS "Country", continent.Name AS "Continent"
        FROM lodging
        INNER JOIN location ON lodging.LocationID = location.ID
        INNER JOIN city ON location.CityID = city.ID
        INNER JOIN state ON location.StateID = state.ID
        INNER JOIN country ON location.CountryID = country.ID
        INNER JOIN continent ON location.ContinentID = continent.ID
        WHERE continent.Name = continent;

    -- Search by country
    ELSEIF country IN (SELECT country.Name FROM country) AND (city = "" AND state = "" AND continent = "") THEN

        -- Query all lodgings from the given continent
        SELECT lodging.Description AS "Lodging", location.Street, city.Name AS "City", state.Name AS "State", country.Name AS "Country", continent.Name AS "Continent"
        FROM lodging
        INNER JOIN location ON lodging.LocationID = location.ID
        INNER JOIN city ON location.CityID = city.ID
        INNER JOIN state ON location.StateID = state.ID
        INNER JOIN country ON location.CountryID = country.ID
        INNER JOIN continent ON location.ContinentID = continent.ID
        WHERE country.Name = country; 

    -- Search by state
    ELSEIF state IN (SELECT state.Name FROM state) AND (city = "" AND country = "" AND continent = "") THEN

        -- Query all lodgings from the given continent
        SELECT lodging.Description AS "Lodging", location.Street, city.Name AS "City", state.Name AS "State", country.Name AS "Country", continent.Name AS "Continent"
        FROM lodging
        INNER JOIN location ON lodging.LocationID = location.ID
        INNER JOIN city ON location.CityID = city.ID
        INNER JOIN state ON location.StateID = state.ID
        INNER JOIN country ON location.CountryID = country.ID
        INNER JOIN continent ON location.ContinentID = continent.ID
        WHERE state.Name = state;   

    -- Search by city
    ELSEIF city IN (SELECT city.Name FROM city) AND (state = "" AND country = "" AND continent = "") THEN

        -- Query all lodgings from the given continent
        SELECT lodging.Description AS "Lodging", location.Street, city.Name AS "City", state.Name AS "State", country.Name AS "Country", continent.Name AS "Continent"
        FROM lodging
        INNER JOIN location ON lodging.LocationID = location.ID
        INNER JOIN city ON location.CityID = city.ID
        INNER JOIN state ON location.StateID = state.ID
        INNER JOIN country ON location.CountryID = country.ID
        INNER JOIN continent ON location.ContinentID = continent.ID
        WHERE city.Name = city;   
    END IF;
END //