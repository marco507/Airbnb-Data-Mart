DELIMITER //

CREATE PROCEDURE Host_CreateALodging(
    IN username VARCHAR(128),
    IN description VARCHAR(128),
    IN category VARCHAR(64),
    IN about TEXT,
    IN capacity INT,
    IN price DECIMAL(7,2),
    IN longitude DECIMAL(17,14),
    IN latitude DECIMAL(17,14),
    IN street VARCHAR(128),
    IN city VARCHAR(128),
    IN state VARCHAR(128),
    IN country VARCHAR(64),
    IN continent VARCHAR(16),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE user_id INT;
    DECLARE city_id INT;
    DECLARE state_id INT;
    DECLARE country_id INT;
    DECLARE continent_id INT;
    DECLARE location_id INT;
    
    -- Check if there are any missing parameters
    IF description = "" OR category = "" OR about = "" OR capacity = 0 OR price = 0 OR latitude = 0 OR longitude = 0 OR street = "" THEN
        SET message = "Creation Failed - Missing Parameters";
    
    ELSE

        -- Check if the user exists
        IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

            -- Check if the continent exists
            IF EXISTS(SELECT * FROM continent WHERE continent.Name = continent) THEN

                -- Check if the country exists
                IF EXISTS(SELECT * FROM country WHERE country.Name = country) THEN        
                    
                    -- Check if the state exists
                    IF EXISTS(SELECT * FROM state WHERE state.Name = state) THEN
          
                        -- Check if the city exists
                        IF EXISTS(SELECT * FROM city WHERE city.Name = city) THEN

                            -- Query the user ID
                            SELECT users.ID INTO user_id FROM users WHERE users.Username = username;
                            -- Query the city ID
                            SELECT city.ID INTO city_id FROM city WHERE city.Name = city;
                            -- Query the state ID
                            SELECT state.ID INTO state_id FROM state WHERE state.Name = state;
                            -- Query the country ID
                            SELECT country.ID INTO country_id FROM country WHERE country.Name = country;
                            -- Query the continent ID
                            SELECT continent.ID INTO continent_id FROM continent WHERE continent.Name = continent;

                            -- Insert the data
                            START TRANSACTION;
                                -- Create a new location
                                INSERT INTO location VALUES(
                                    DEFAULT,
                                    longitude,
                                    latitude,
                                    street,
                                    city_id,
                                    state_id,
                                    country_id,
                                    continent_id
                                );
                                -- Save the ID of the location
                                SELECT LAST_INSERT_ID() INTO location_id;

                                -- Create a new lodging
                                INSERT INTO lodging (ID, Description, Category, About, Capacity, Price, CurrencyID, LocationID, UsersID)
                                VALUES(DEFAULT, description, category, about, capacity,price, (SELECT users.CurrencyID FROM users WHERE users.ID = user_id), location_id, user_id);

                                -- If the user was a only a guest user, set the user to host
                                IF EXISTS(SELECT * FROM users WHERE users.ID = user_id AND users.HostID IS NULL) THEN
                                    UPDATE users SET users.HostID = user_id WHERE users.ID = user_id;
                                END IF;

                                -- Return a success message
                                SET message = "Lodging Created";

                                COMMIT;
                                
                        -- Invalid State
                        ELSE
                            SET message = "Creation Failed - City Not Found";
                        END IF;

                    -- Invalid State
                    ELSE
                        SET message = "Creation Failed - State Not Found";
                    END IF;

                -- Invalid State
                ELSE
                    SET message = "Creation Failed - Country Not Found";
                END IF;
            
            -- Invalid City
            ELSE
                SET message = "Creation Failed - Continent Not Found";
            END IF;

        -- Invalid username
        ELSE
            SET message = 'Creation Failed - User Not Found';
        END IF;
    END IF;
END //