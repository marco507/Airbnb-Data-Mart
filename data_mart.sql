-- phpMyAdmin SQL Dump
-- version 5.0.4
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Erstellungszeit: 19. Jul 2021 um 14:25
-- Server-Version: 10.4.17-MariaDB
-- PHP-Version: 8.0.2

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Datenbank: `data_mart`
--

DELIMITER $$
--
-- Prozeduren
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_BookAStay` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `arrival` DATE, IN `departure` DATE, IN `payment_option` VARCHAR(64), OUT `message` VARCHAR(128))  BEGIN
    -- Declare Variables
    DECLARE number_of_bookings INT;
    DECLARE user_id INT;
    DECLARE lodging_id INT;
    DECLARE last_booking INT;
    DECLARE amount DECIMAL(19,2);
    DECLARE stay_duration DECIMAL(6,2);
    
    -- Check if the lodging exists
    IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

        -- Query the lodging ID
        SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;
    
    	-- Check if the user exists
        IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN
        
        	-- Check if the paymentoption exists
            IF EXISTS(SELECT * FROM paymentoption WHERE paymentoption.Name = payment_option) THEN
        
                -- Query the users ID
                SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

                -- Check if the arrival date is in the future and the departure date is after the arrival date
                IF arrival < departure AND arrival > CURRENT_DATE THEN 

                    -- Check if there are any date conflicts for the booking
                    IF EXISTS(SELECT * FROM booking WHERE ( arrival BETWEEN booking.Arrival AND booking.Departure ) AND booking.LodgingID = lodging_id ) THEN
                        -- Return an error message
                        SET message = 'Booking Failed - The lodging is already reserved for that date';

                    -- Make a reservation         
                    ELSE
                        START TRANSACTION;
                            -- Insert the reservation into the booking table
                            INSERT INTO booking VALUES(DEFAULT, arrival, departure, user_id, lodging_id);
                      		-- Save the ID of the last reservation
                      		SELECT LAST_INSERT_ID() INTO last_booking;

			                -- Calculate the duration of the stay
                            SELECT DATEDIFF(departure, arrival) INTO stay_duration;
                            
                            -- Calculate the price of the stay = LodgingPricePerNight * DurationOfStay * 5%Commission
                             SELECT lodging.Price INTO amount FROM lodging WHERE lodging.ID = lodging_id;
                             SET amount = amount * stay_duration * 1.05;
                             SET amount = CONVERT(amount,DECIMAL(19,2));
       
                            -- Create the corresponding transaction
                            INSERT INTO transactions VALUES(
                                DEFAULT,
                                amount,
                                (SELECT lodging.Price FROM lodging WHERE lodging.ID = lodging_id), 
                                (SELECT lodging.CurrencyID FROM lodging WHERE lodging.ID = lodging_id), 
                                DEFAULT, 
                                DEFAULT, 
                                (SELECT currency.ExchangeRate FROM currency WHERE currency.ID = (SELECT lodging.CurrencyID FROM lodging WHERE lodging.ID = lodging_id )),
                                (SELECT currency.ExchangeRate FROM currency WHERE currency.ID = (SELECT users.CurrencyID FROM users WHERE users.Username = username)),
                                (SELECT paymentoption.ID FROM paymentoption WHERE paymentoption.Name = payment_option),
                                last_booking
                                );
                            SET message = 'Reservation made';
                      	COMMIT;
                    END IF;

                -- Date Check Failed
                ELSE
                    SET message = 'Booking Failed - False Date';
                END IF;
                                
            -- Invalid Paymentoption
            ELSE
                SET message = 'Booking Failed - False Payment Option';
            END IF;
                                        
        -- Invalid Username
        ELSE
            SET message = 'Booking Failed - False Username';
        END IF;
	
    -- Invalid Lodging Name
    ELSE
    	SET message = 'Booking Failed - No Lodging Found';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_CloseOpenTransaction` (IN `username` VARCHAR(128), IN `amount` DECIMAL(19,2), IN `transaction_id` INT, OUT `message` VARCHAR(128))  BEGIN
    DECLARE converted_amount DECIMAL(19,2);
    DECLARE exchange_guest VARCHAR(64);
    DECLARE exchange_lodging VARCHAR(64);

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if there are open transactions corresponding to the given ID
        IF EXISTS(SELECT * FROM transactions WHERE transactions.ID = transaction_id AND transactions.Received = 0) THEN

            -- Query the exchange rates of the transaction
            SELECT transactions.ExchangeEuroLodging, transactions.ExchangeEuroGuest INTO exchange_lodging, exchange_guest FROM transactions
            WHERE transactions.ID = transaction_id; 

            -- Convert the given amount into the transactions currency
            SET converted_amount = ROUND(amount * exchange_guest / exchange_lodging, 2);

            -- Check if the given amount is the same as in the transaction (Amount approximately +/- 1 currency unit to account for rounding errors)
            IF (SELECT transactions.Amount FROM transactions WHERE transactions.ID = transaction_id) BETWEEN converted_amount - 1 AND converted_amount + 1 THEN
            
                -- Set the transaction to received
                UPDATE transactions SET transactions.Received = 1 WHERE transactions.ID = transaction_id;

                -- Return a success message
                SET message = "Set Transaction To Received";

            -- No transaction found
            ELSE
                SET message = "Action Failed - False Amount";
            END IF;

        -- Given amount does not correspond to a transaction
        ELSE
            SET message = "Action Failed - No Open Transaction Found";
        END IF;

    -- Invalid username
    ELSE
        SET message = "Action Failed - User Not Found";
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_SearchALodging` (IN `category` VARCHAR(64), IN `capacity` INT, IN `city` VARCHAR(128))  BEGIN

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

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_SearchGeographically` (IN `city` VARCHAR(128), IN `state` VARCHAR(128), IN `country` VARCHAR(64), IN `continent` VARCHAR(16))  BEGIN

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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_SearchNearbyLocations` (IN `lodging` VARCHAR(128), IN `distance` DECIMAL(4,1), OUT `message` VARCHAR(128))  BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_ShowLodgingDetails` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), OUT `message` VARCHAR(128))  BEGIN
    DECLARE exchange_guest DECIMAL(20,9);
    DECLARE exchange_host DECIMAL(20,9);

    -- Check if the lodging exists
    IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

            -- Check if the username exists
            IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

            -- Query the current exchange rates of the guest and host
            SELECT currency.ExchangeRate INTO exchange_guest FROM currency
            INNER JOIN users ON users.CurrencyID = currency.ID
            WHERE users.username = username;

            SELECT currency.ExchangeRate INTO exchange_host FROM currency
            INNER JOIN lodging ON lodging.CurrencyID = currency.ID
            WHERE lodging.Description = lodging;

            -- Query the category, capacity and converted price of the lodging
            SELECT lodging.category, lodging.capacity, lodging.Rating, 
            (ROUND(lodging.Price * exchange_host / exchange_guest, 2)) AS "Price", 
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS "Currency"
            FROM lodging
            WHERE lodging.Description = lodging;

            -- Query all furniture of the lodging
            SELECT furnishing.Description AS "Furniture"
            FROM lodging
            INNER JOIN lodging_furnishing ON lodging_furnishing.LodgingID = lodging.ID
            INNER JOIN furnishing ON lodging_furnishing.FurnishingID = furnishing.ID
            WHERE lodging.Description = lodging;

            -- Query all rooms of the lodging
            SELECT room.Description AS "Room", lodging_room.Number
            FROM lodging
            INNER JOIN lodging_room ON lodging_room.LodgingID = lodging.ID
            INNER JOIN room ON lodging_room.RoomID = room.ID
            WHERE lodging.Description = lodging;

            -- Query all rules of the lodging
            SELECT rule.Description AS "Rule"
            FROM lodging
            INNER JOIN lodging_rule ON lodging_rule.LodgingID = lodging.ID
            INNER JOIN rule ON lodging_rule.RuleID = rule.ID
            WHERE lodging.Description = lodging;

            -- Query all policies of the lodging
            SELECT policy.Description AS "Policy"
            FROM lodging
            INNER JOIN lodging_policy ON lodging_policy.LodgingID = lodging.ID
            INNER JOIN policy ON lodging_policy.PolicyID = policy.ID
            WHERE lodging.Description = lodging;

            -- Query all reviews of the lodging
            SELECT review.Content AS "Review", review.Rating
            FROM review
            INNER JOIN booking ON review.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.Description = lodging;

            -- Return an message
            SET message = "Results";

        -- Incorrect username
        ELSE
            SET message = "Search Failed - User Not Found";
        END IF;

    -- Lodging does not exist
    ELSE
        SET message = "Search Failed - Lodging Not Found";
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Guest_WriteAReview` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `departure` DATE, IN `review` TEXT, IN `rating` DECIMAL(2,1), OUT `message` VARCHAR(128))  BEGIN

    DECLARE user_id INT;
    DECLARE lodging_id INT;
    DECLARE rating_sum FLOAT;
    DECLARE rating_count FLOAT;
    DECLARE new_rating DECIMAL(2,1);

    -- Check if the username exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

            -- Check if the review or rating is missing
            IF review = '' OR rating = 0 THEN
                -- Return an error message
                SET message = 'Review Failed - Missing Parameters';

            ELSE
                -- Query the lodging ID
                SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

                -- Query the users ID
                SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

                    -- Check if the user is authorized to issue a review ( A booking exists for a user at a certain departure date )
                    IF EXISTS(SELECT * FROM booking WHERE (booking.LodgingID = lodging_id AND booking.UsersID = user_id AND booking.Departure = departure) ) THEN
                    
                        -- Check if there is already a review
                        IF EXISTS(SELECT * FROM review WHERE review.BookingID = (SELECT booking.ID FROM booking WHERE booking.UsersID = user_id AND booking.LodgingID = lodging_id)) THEN
                            -- Return an error message
                            SET message = "Review Failed - Only One Review Allowed";

                        -- Create a new entry for the review
                        ELSE    
                            START TRANSACTION;
                                INSERT INTO review 
                                VALUES(
                                    DEFAULT,
                                    review,
                                    rating,
                                    (SELECT booking.ID FROM booking WHERE booking.LodgingID = lodging_id AND booking.UsersID = user_id AND booking.Departure = departure)
                                );

                                -- Calculate the new rating of the lodging
                                SELECT SUM(review.Rating), COUNT(review.Rating) 
                                INTO rating_sum, rating_count 
                                FROM review
                                INNER JOIN booking ON review.BookingID = booking.ID
                                INNER JOIN lodging ON booking.LodgingID = lodging.ID
                                WHERE lodging.ID = lodging_id;

                                UPDATE lodging SET lodging.Rating = rating_sum / rating_count WHERE lodging.ID = lodging_id;

                                SET message = "Review Inserted";
                            COMMIT;
                        END IF;
            
                    -- No corresponding booking found
                    ELSE
                        SET message = "Review Failed - No Booking Found";
                    END IF;
            END IF;

        -- Invalid Lodging Name
        ELSE
            SET message = 'Review Failed - No Lodging Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Review Failed - False Username';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_CreateALodging` (IN `username` VARCHAR(128), IN `description` VARCHAR(128), IN `category` VARCHAR(64), IN `about` TEXT, IN `capacity` INT, IN `price` DECIMAL(7,2), IN `longitude` DECIMAL(17,14), IN `latitude` DECIMAL(17,14), IN `street` VARCHAR(128), IN `city` VARCHAR(128), IN `state` VARCHAR(128), IN `country` VARCHAR(64), IN `continent` VARCHAR(16), OUT `message` VARCHAR(128))  BEGIN
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

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_DeleteLodging` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), OUT `message` VARCHAR(128))  BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    DECLARE location_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to remove the lodging (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN

                -- Check if there is at least one booking
                IF EXISTS(SELECT * FROM booking WHERE booking.LodgingID = lodging_id) THEN
                
                    -- Check if there are open transactions
                        IF EXISTS(
                            SELECT * FROM transactions 
                            INNER JOIN booking ON transactions.BookingID = booking.ID
                            WHERE booking.LodgingID = lodging_id AND (transactions.Received = 0 OR transactions.Settled = 0)) THEN

                                SET message = 'Deletion Failed - Not Settled Transactions';

                        -- All transactions settled
                        ELSE
                            START TRANSACTION;
                                -- Query the location ID
                                SELECT LocationID INTO location_id FROM lodging WHERE ID = lodging_id;
                                -- Delete the Lodging
                                DELETE FROM lodging WHERE ID = lodging_id;
                                -- Delete the Location of the Lodging
                                DELETE FROM location WHERE location.ID = location_id;

                                -- If the host deleted all his lodging he becomes a guest
                                IF NOT EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id) THEN
                                    UPDATE users SET users.HostID = NULL WHERE users.ID = user_id;
                                END IF;

                                -- Return a success mesagge
                                SET message = 'Lodging Deleted';
                            COMMIT;
                        END IF;
                
                -- No bookings = No open transactions and the lodging can be deleted
                ELSE
                    SET message = 'Lodging Deleted';
                END IF;
        
            -- User is not the owner
            ELSE
                SET message = 'Deletion Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Deletion Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Deletion Failed - User Not Found';
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_ManageFurniture` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `furniture` VARCHAR(256), IN `action` VARCHAR(6), OUT `message` VARCHAR(128))  BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging furniture (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Furniture should be added
                IF action = 'Add' THEN
                
                    -- INSERT the Furniture
                    INSERT INTO lodging_furnishing SELECT lodging_id, furnishing.ID FROM furnishing WHERE FIND_IN_SET(furnishing.Description,furniture);

                    -- Return a success message
                    SET message = 'Added Furniture';
                
                -- Furniture should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Furniture
                    DELETE FROM lodging_furnishing
                    WHERE lodging_furnishing.LodgingID = lodging_id
                    AND lodging_furnishing.FurnishingID IN (SELECT furnishing.ID FROM furnishing WHERE FIND_IN_SET(furnishing.Description,furniture));  

                    -- Return a success message
                    SET message = 'Removed Furniture';
                
                -- Invalid Command
                ELSE
                    SET message = 'Furnishing Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Furnishing Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Furnishing Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Furnishing Failed - User Not Found';
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_ManagePolicies` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `policies` VARCHAR(256), IN `action` VARCHAR(6), OUT `message` VARCHAR(128))  BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging policy (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Policy should be added
                IF action = 'Add' THEN
                
                    -- INSERT the Policy
                    INSERT INTO lodging_policy SELECT lodging_id, policy.ID FROM policy WHERE FIND_IN_SET(policy.ID,policies);

                    -- Return a success message
                    SET message = 'Added Policy';
                
                -- Policy should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Policy
                    DELETE FROM lodging_policy
                    WHERE lodging_policy.LodgingID = lodging_id
                    AND lodging_policy.PolicyID IN (SELECT policy.ID FROM policy WHERE FIND_IN_SET(policy.ID,policies));  

                    -- Return a success message
                    SET message = 'Removed Policy';
                
                -- Invalid Command
                ELSE
                    SET message = 'Action Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Action Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Action Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Action Failed - User Not Found';
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_ManageRooms` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `rooms` VARCHAR(256), IN `amount` VARCHAR(256), IN `action` VARCHAR(6), OUT `message` VARCHAR(128))  BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    DECLARE list_length INT;
    DECLARE i INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging rooms (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Rooms should be added
                IF action = 'Add' THEN
                
                    -- Count the number of items in the rooms list
                    SELECT 
                    CHARACTER_LENGTH(rooms)  - 
                    CHARACTER_LENGTH(REPLACE(rooms,',',''))
                    INTO list_length;

                    -- Insert the rooms one-by-one
                    SET i = 1;
                    insert_loop: WHILE i <= list_length + 1 DO

                        INSERT INTO lodging_room VALUES(
                            lodging_id,
                            (SELECT room.ID FROM room WHERE room.Description = SUBSTRING_INDEX(SUBSTRING_INDEX(rooms,',',i),',',-1)),
                            (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(amount,',',FIND_IN_SET(SUBSTRING_INDEX(SUBSTRING_INDEX(rooms,',',i),',',-1), rooms)), ',', -1))
                        );

                        SET i = i+1;
                    END WHILE insert_loop;

                    -- Return a success message
                    SET message = 'Added Rooms';
                
                -- Rooms should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Rooms
                    DELETE FROM lodging_room
                    WHERE lodging_room.LodgingID = lodging_id
                    AND lodging_room.RoomID IN (SELECT room.ID FROM room WHERE FIND_IN_SET(room.Description,rooms));  

                    -- Return a success message
                    SET message = 'Removed Rooms';
                
                -- Invalid Command
                ELSE
                    SET message = 'Action Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Action Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Action Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Action Failed - User Not Found';
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_ManageRules` (IN `username` VARCHAR(128), IN `lodging` VARCHAR(128), IN `rules` VARCHAR(256), IN `action` VARCHAR(6), OUT `message` VARCHAR(128))  BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging rules (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Rule should be added
                IF action = 'Add' THEN
                
                    -- INSERT the Rule
                    INSERT INTO lodging_rule SELECT lodging_id, rule.ID FROM rule WHERE FIND_IN_SET(rule.Description,rules);

                    -- Return a success message
                    SET message = 'Added Rule';
                
                -- Rule should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Rule
                    DELETE FROM lodging_rule
                    WHERE lodging_rule.LodgingID = lodging_id
                    AND lodging_rule.RuleID IN (SELECT rule.ID FROM rule WHERE FIND_IN_SET(rule.Description,rules));  

                    -- Return a success message
                    SET message = 'Removed Rule';
                
                -- Invalid Command
                ELSE
                    SET message = 'Action Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Action Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Action Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Action Failed - User Not Found';
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Host_SettleOpenTransactions` (IN `username` VARCHAR(128), OUT `message` VARCHAR(128))  BEGIN

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if there are unsettled transactions and received transactions
        IF EXISTS(
            SELECT * FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0) THEN

            -- Set the unsettled transactions to settled
            UPDATE transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            SET transactions.Settled = 1
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0;

            -- Return a success message
            SET message = "Transactions Set to Settled And Payment Initiated";

        -- No unsettled transactions
        ELSE
            SET message = "Action Failed - No Unsettled Transactions";
        END IF;

    -- User does not exist
    ELSE
        SET message = "Action Failed - User does not exist";
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `User_CreateUser` (IN `username` VARCHAR(128), IN `firstname` VARCHAR(128), IN `lastname` VARCHAR(128), IN `email` VARCHAR(128), IN `phone` VARCHAR(20), IN `currency` VARCHAR(64), IN `about` TEXT, OUT `message` VARCHAR(128))  BEGIN
    -- Declare Variables
    DECLARE currency_id INT;

    -- Check if all necessary parameters are issued
    IF username = '' OR firstname = '' OR lastname = '' OR email = '' OR phone = '' OR currency = '' THEN
    	SET message = 'User Creation Failed - Parameters Missing';
        
    -- If all parameters are issued proceed
    ELSE
        -- Check if the currency value is correct
    	IF EXISTS(SELECT * FROM currency WHERE currency.Name = currency) THEN

            -- Query the currency ID with the currency name
            SELECT currency.ID INTO currency_id FROM currency WHERE currency.Name = currency;

            -- Create a new user
            INSERT INTO users (ID, username, firstname, lastname, email, phone, about, CurrencyID)
            VALUES (DEFAULT, username, firstname, lastname , email , phone, about, currency_id);
            SET message = 'New User Created';

        -- If the currency has a wrong value return an error
        ELSE
            SET message = 'User Creation Failed - Wrong Currency Value';
        END IF;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `User_DeleteAccount` (IN `username` VARCHAR(128), OUT `message` VARCHAR(128))  BEGIN
	-- Declare Variables
    DECLARE is_host INT;
    DECLARE all_settled INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN
    
        -- Check if a user is a host or guest
        SELECT users.HostID 
        INTO is_host
        FROM users
        WHERE users.Username = username;

        -- If the user is a guest check for not received transactions
        IF is_host IS NULL THEN
            -- Query and count the unreceived transactions of the guest 
            SELECT COUNT(transactions.Received)
            INTO all_settled
            FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN users ON booking.UsersID = users.ID 
            WHERE users.Username = username AND transactions.Received = 0;

            -- If all transactions are closed, delete the user
            IF all_settled = 0 THEN      
                DELETE FROM users WHERE users.Username = username;
                SET message = 'Account Deleted';

            -- If there are open transactions, give back an error message
            ELSE
                SET message = 'Deactivation Failed - Open Transaction';
            END IF;

        -- If the user is a host check for not settled transactions
        ELSE
            -- Query and count the unsettled transactions of the host 
            SELECT COUNT(transactions.Settled)
            INTO all_settled
            FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            INNER JOIN users ON lodging.UsersID = users.ID 
            WHERE users.Username = username AND transactions.Settled = 0;

            -- If all transactions are closed, delete the first the location of all lodgings and then the user
            IF all_settled = 0 THEN

                START TRANSACTION;
                    
                    -- Query the ID's of the locations and save them
                    CREATE TEMPORARY TABLE delete_user_location_results 
                    AS (SELECT lodging.LocationID FROM lodging WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username));

                    -- Delete the user
                    DELETE FROM users WHERE users.Username = username;
                    
                    -- Delete all locations of the users lodgings
                    DELETE FROM location 
                    WHERE location.ID IN (SELECT LocationID FROM delete_user_location_results);

                    SET message = 'Account Deleted';
                COMMIT;

            -- If there are open transactions, give back an error message
            ELSE
                SET message = 'Deactivation Failed - Open Transaction';
            END IF;
        END IF;
	
    -- If the user does not exists return an error message
    ELSE
    	SET message = 'Deactivation Failed - User Does Not Exist';
    END IF;
	
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `User_ShowOpenTransactions` (IN `username` VARCHAR(128), OUT `message` VARCHAR(128))  BEGIN
    -- Declare Varibles
    DECLARE is_host INT;

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if a user is a host or guest
        SELECT users.HostID 
        INTO is_host
        FROM users
        WHERE users.Username = username;

        IF is_host IS NULL THEN

            -- Query all unreceived transactions
            SELECT transactions.ID,
            "Unreceived" AS "Status", 
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS Total,
            "5%" AS "Fee",
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE booking.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 0;

        ELSE
            
            -- Query all unreceived transactions
            SELECT transactions.ID,
            "Unreceived" AS "Status", 
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS Total,
            "5%" AS "Fee",
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE booking.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 0;

            -- Query all unsettled transactions
            SELECT transactions.ID,
            "Unsettled" AS "Status",
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest * (100 / 105) ,2)) AS Total,
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description AS Lodging FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0;
        END IF;

        -- Return a status message
        SET message = "Result";
        
    -- User does not exist
    ELSE
        SET message = "Search Failed - User does not exist";
    END IF;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `booking`
--

CREATE TABLE `booking` (
  `ID` int(11) NOT NULL,
  `Arrival` date NOT NULL,
  `Departure` date NOT NULL,
  `UsersID` int(11) DEFAULT NULL,
  `LodgingID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `booking`
--

INSERT INTO `booking` (`ID`, `Arrival`, `Departure`, `UsersID`, `LodgingID`) VALUES
(1, '2020-01-04', '2020-01-05', 20, 1),
(2, '2020-04-01', '2020-04-09', 18, 1),
(3, '2020-09-07', '2020-09-13', 16, 2),
(4, '2020-10-23', '2020-11-01', 14, 2),
(5, '2020-05-04', '2020-05-07', 12, 3),
(6, '2020-02-08', '2020-02-13', 10, 3),
(7, '2020-08-04', '2020-08-10', 8, 4),
(8, '2020-07-01', '2020-07-06', 6, 4),
(9, '2020-12-13', '2020-12-20', 4, 5),
(10, '2020-01-01', '2020-01-04', 2, 5),
(11, '2020-05-06', '2020-05-09', 2, 6),
(12, '2020-02-08', '2020-02-12', 4, 6),
(13, '2020-03-28', '2020-04-02', 6, 7),
(14, '2020-01-07', '2020-01-10', 8, 7),
(15, '2020-03-02', '2020-03-05', 10, 8),
(16, '2020-07-07', '2020-07-09', 12, 8),
(17, '2020-09-03', '2020-09-14', 14, 9),
(18, '2020-01-05', '2020-01-09', 16, 9),
(19, '2020-08-07', '2020-08-12', 18, 10),
(20, '2020-01-04', '2020-01-05', 20, 10),
(21, '2020-04-01', '2020-04-09', 20, 11),
(22, '2020-09-07', '2020-09-13', 18, 11),
(23, '2020-10-23', '2020-11-01', 16, 12),
(24, '2020-05-04', '2020-05-07', 14, 12),
(25, '2020-02-08', '2020-02-13', 12, 13),
(26, '2020-08-04', '2020-08-10', 10, 13),
(27, '2020-07-01', '2020-07-06', 8, 14),
(28, '2020-12-13', '2020-12-20', 6, 14),
(29, '2020-01-01', '2020-01-04', 4, 15),
(30, '2020-05-06', '2020-05-09', 2, 15),
(31, '2020-02-08', '2020-02-12', 2, 16),
(32, '2020-03-28', '2020-04-02', 4, 16),
(33, '2020-01-07', '2020-01-10', 6, 17),
(34, '2020-03-02', '2020-03-05', 8, 17),
(35, '2020-07-07', '2020-07-09', 10, 18),
(36, '2020-09-03', '2020-09-14', 12, 18),
(37, '2020-01-05', '2020-01-09', 14, 19),
(38, '2020-08-07', '2020-08-12', 16, 19),
(39, '2020-01-15', '2020-01-18', 18, 20),
(40, '2020-08-25', '2020-08-29', 20, 20);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `city`
--

CREATE TABLE `city` (
  `ID` int(11) NOT NULL,
  `Name` varchar(128) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `city`
--

INSERT INTO `city` (`ID`, `Name`) VALUES
(1, 'Aachen'),
(2, 'Aalborg'),
(3, 'Aarau'),
(4, 'Aarhus'),
(5, 'Aarri'),
(6, 'Aba'),
(7, 'Abaetetuba'),
(8, 'Abakan'),
(9, 'Abancay'),
(10, 'Abeokuta'),
(11, 'Aberdeen'),
(12, 'Aberystwyth'),
(13, 'Abidjan'),
(14, 'Abilene'),
(15, 'Abu Dhabi'),
(16, 'Abuja'),
(17, 'Acapulco'),
(18, 'Acarigua'),
(19, 'Accra'),
(20, 'Acheng'),
(21, 'Achinsk'),
(22, 'ad Damir'),
(23, 'Adamstown'),
(24, 'Adana'),
(25, 'Adapazari'),
(26, 'Addis Ababa'),
(27, 'Adelaide'),
(28, 'Aden'),
(29, 'Adiyaman'),
(30, 'Ado Ekiti'),
(31, 'Afyon'),
(32, 'Agadir'),
(33, 'Agana'),
(34, 'Agartala'),
(35, 'Agra'),
(36, 'Agri'),
(37, 'Aguascalientes'),
(38, 'Ahmadabad'),
(39, 'Ahvaz'),
(40, 'Aijal'),
(41, 'Aix en Provence'),
(42, 'Ajaccio'),
(43, 'Ajmer'),
(44, 'Akita'),
(45, 'Akron'),
(46, 'Aksaray'),
(47, 'Aksu'),
(48, 'Akure'),
(49, 'Akureyri'),
(50, 'Akyab'),
(51, 'Al Amarah'),
(52, 'Al Ayn'),
(53, 'Al Basrah'),
(54, 'al Fasher'),
(55, 'Al Hillah'),
(56, 'Al Kut'),
(57, 'al Qadarif'),
(58, 'al Ubayyid'),
(59, 'Alagoinhas'),
(60, 'Alajuela'),
(61, 'Alba Iulia'),
(62, 'Albacete'),
(63, 'Albany'),
(64, 'Albuquerque'),
(65, 'Alcala de Henares'),
(66, 'Alcorcon'),
(67, 'Aleppo'),
(68, 'Alexandria'),
(69, 'Algeciras'),
(70, 'Algier'),
(71, 'Alicante'),
(72, 'Aligarh'),
(73, 'Allahabad'),
(74, 'Allentown'),
(75, 'Almada'),
(76, 'Almaty'),
(77, 'Almeria'),
(78, 'Almetyevsk'),
(79, 'Alofi'),
(80, 'Alor Setar'),
(81, 'Altdorf'),
(82, 'Alvorada'),
(83, 'Amadora'),
(84, 'Amarillo'),
(85, 'Amasya'),
(86, 'Ambon'),
(87, 'Americana'),
(88, 'Amiens'),
(89, 'Amman'),
(90, 'Amol'),
(91, 'Amravati'),
(92, 'Amritsar'),
(93, 'Amsterdam'),
(94, 'An Najaf'),
(95, 'An Nasiriyah'),
(96, 'Anadyr'),
(97, 'Anaheim'),
(98, 'Ananindeua'),
(99, 'Anapolis'),
(100, 'Anchorage'),
(101, 'Ancona'),
(102, 'Anda'),
(103, 'Andijon'),
(104, 'Andorra la Vella'),
(105, 'Angarsk'),
(106, 'Angers'),
(107, 'Angren'),
(108, 'Anju'),
(109, 'Ankang'),
(110, 'Ankara'),
(111, 'Ann Arbor'),
(112, 'Annaba'),
(113, 'Annapolis'),
(114, 'Anqing'),
(115, 'Anshan'),
(116, 'Anshun'),
(117, 'Antakya'),
(118, 'Antalya'),
(119, 'Antananarivo'),
(120, 'Antsirabe'),
(121, 'Antsiranana'),
(122, 'Antwerp'),
(123, 'Anyang'),
(124, 'Anzhero Sudzhensk'),
(125, 'Aomori'),
(126, 'Aosta'),
(127, 'Aparecida de Goiania'),
(128, 'Apia'),
(129, 'Apopa'),
(130, 'Appenzell'),
(131, 'Apucarana'),
(132, 'Aqmola'),
(133, 'Aqtau'),
(134, 'Aqtobe'),
(135, 'Ar Ramadi'),
(136, 'Aracaju'),
(137, 'Aracatuba'),
(138, 'Arad'),
(139, 'Araguaina'),
(140, 'Arak'),
(141, 'Arapiraca'),
(142, 'Araraquara'),
(143, 'Arauca'),
(144, 'Arbil'),
(145, 'Ardabil'),
(146, 'Arendal'),
(147, 'Arequipa'),
(148, 'Arkhangelsk'),
(149, 'Arlington'),
(150, 'Arlon'),
(151, 'Armavir'),
(152, 'Armenia'),
(153, 'Arnhem'),
(154, 'Arqalyq'),
(155, 'Artvin'),
(156, 'Arusha'),
(157, 'Arzamas'),
(158, 'As Samawah'),
(159, 'As Sulaymaniyah'),
(160, 'Ashgabat'),
(161, 'Asmara'),
(162, 'Assen'),
(163, 'Astrakhan'),
(164, 'Asuncion'),
(165, 'Aswan'),
(166, 'Asyut'),
(167, 'Athens'),
(168, 'Atizapan de Zaragoza'),
(169, 'Atlanta'),
(170, 'Atyrau'),
(171, 'Auckland'),
(172, 'Augsburg'),
(173, 'Augusta'),
(174, 'Aurangabad'),
(175, 'Aurora'),
(176, 'Austin'),
(177, 'Avarua'),
(178, 'Aveiro'),
(179, 'Avellaneda'),
(180, 'Ayacucho'),
(181, 'Aydin'),
(182, 'Aylesbury'),
(183, 'Babol'),
(184, 'Bacau'),
(185, 'Badajoz'),
(186, 'Badalona'),
(187, 'Bafoussam'),
(188, 'Bage'),
(189, 'Baghdad'),
(190, 'Bago'),
(191, 'Bahawalpur'),
(192, 'Bahia Blanca'),
(193, 'Bahir Dar'),
(194, 'Baia Mare'),
(195, 'Baicheng'),
(196, 'Baiyin'),
(197, 'Bakersfield'),
(198, 'Bakhtaran'),
(199, 'Baku'),
(200, 'Balakovo'),
(201, 'Balashikha'),
(202, 'Balikesir'),
(203, 'Balikpapan'),
(204, 'Baltimore'),
(205, 'Bamako'),
(206, 'Bamenda'),
(207, 'Banda Aceh'),
(208, 'Bandar Abbas'),
(209, 'Bandar e Bushehr'),
(210, 'Bandar Lampung'),
(211, 'Bandar Seri Begawan'),
(212, 'Bandundu'),
(213, 'Bandung'),
(214, 'Bangalore'),
(215, 'Bangkok'),
(216, 'Bangui'),
(217, 'Banjarmasin'),
(218, 'Banjul'),
(219, 'Baoding'),
(220, 'Baoji'),
(221, 'Baotou'),
(222, 'Baqubah'),
(223, 'Baracaldo'),
(224, 'Barbacena'),
(225, 'Barcelona'),
(226, 'Bareilly'),
(227, 'Bari'),
(228, 'Barinas'),
(229, 'Barisal'),
(230, 'Barnaul'),
(231, 'Barnsley'),
(232, 'Barquisimeto'),
(233, 'Barra Mansa'),
(234, 'Barrancabermeja'),
(235, 'Barranquilla'),
(236, 'Barreiras'),
(237, 'Barreiro'),
(238, 'Barretos'),
(239, 'Barry'),
(240, 'Barueri'),
(241, 'Baruta'),
(242, 'Basel'),
(243, 'Basildon'),
(244, 'Basingstoke'),
(245, 'Basse-Terre'),
(246, 'Basseterre'),
(247, 'Batam'),
(248, 'Batman'),
(249, 'Batna'),
(250, 'Baton Rouge'),
(251, 'Bauru'),
(252, 'Bayamo'),
(253, 'Bayburt'),
(254, 'Beaumont'),
(255, 'Bechar'),
(256, 'Bedford'),
(257, 'Beer Sheva'),
(258, 'Beian'),
(259, 'Beihai'),
(260, 'Beijing'),
(261, 'Beipiao'),
(262, 'Beira'),
(263, 'Beirut'),
(264, 'Beja'),
(265, 'Bejaia'),
(266, 'Bekescaba'),
(267, 'Belem'),
(268, 'Belfast'),
(269, 'Belfort Roxo'),
(270, 'Belgorod'),
(271, 'Belgrade'),
(272, 'Bellinzona'),
(273, 'Bello'),
(274, 'Belmopan'),
(275, 'Belo Horizonte'),
(276, 'Bengasi'),
(277, 'Bengbu'),
(278, 'Bengkulu'),
(279, 'Benguela'),
(280, 'Benha'),
(281, 'Beni Mellal'),
(282, 'Beni Suef'),
(283, 'Benin City'),
(284, 'Benoni'),
(285, 'Benxi'),
(286, 'Berezniki'),
(287, 'Bergamo'),
(288, 'Bergen'),
(289, 'Bergisch Gladbach'),
(290, 'Berkeley'),
(291, 'Berlin'),
(292, 'Bern'),
(293, 'Bertoua'),
(294, 'Besancon'),
(295, 'Betim'),
(296, 'Beverley'),
(297, 'Bhatpara'),
(298, 'Bhavnagar'),
(299, 'Bhilai'),
(300, 'Bhiwandi'),
(301, 'Bhopal'),
(302, 'Bhubaneswar'),
(303, 'Biala Podlaska'),
(304, 'Bialystok'),
(305, 'Bida'),
(306, 'Bie'),
(307, 'Biel'),
(308, 'Bielefeld'),
(309, 'Bielsko Biala'),
(310, 'Bikaner'),
(311, 'Bilbao'),
(312, 'Bilecik'),
(313, 'Bingol'),
(314, 'Binjai'),
(315, 'Birjand'),
(316, 'Birmingham'),
(317, 'Birobidzhan'),
(318, 'Bishkek'),
(319, 'Bisho'),
(320, 'Bismarck'),
(321, 'Bissau'),
(322, 'Bistrita'),
(323, 'Bitlis'),
(324, 'Biysk'),
(325, 'Blackburn'),
(326, 'Blackpool'),
(327, 'Blagoveshchensk'),
(328, 'Blida'),
(329, 'Blitar'),
(330, 'Bloemfontein'),
(331, 'Blumenau'),
(332, 'Boa Vista'),
(333, 'Bocas del Toro'),
(334, 'Bochum'),
(335, 'Bodoe'),
(336, 'Bogor'),
(337, 'Bogota'),
(338, 'Bogra'),
(339, 'Boise'),
(340, 'Bojnurd'),
(341, 'Bokara Steel City'),
(342, 'Boksburg'),
(343, 'Bologna'),
(344, 'Bolton'),
(345, 'Bolu'),
(346, 'Bolzano'),
(347, 'Boma'),
(348, 'Bombay'),
(349, 'Bonn'),
(350, 'Bordeaux'),
(351, 'Borujerd'),
(352, 'Boston'),
(353, 'Botosani'),
(354, 'Bottrop'),
(355, 'Botucatu'),
(356, 'Boulogne Billancourt'),
(357, 'Bournemouth'),
(358, 'Bracknell'),
(359, 'Bradford'),
(360, 'Braga'),
(361, 'Braganca'),
(362, 'Braganca Paulista'),
(363, 'Brahmanbaria'),
(364, 'Braila'),
(365, 'Braintree'),
(366, 'Brampton'),
(367, 'Brasilia'),
(368, 'Brasov'),
(369, 'Bratislava'),
(370, 'Bratsk'),
(371, 'Braunschweig'),
(372, 'Brazzaville'),
(373, 'Breda'),
(374, 'Bregenz'),
(375, 'Bremen'),
(376, 'Bremerhaven'),
(377, 'Brescia'),
(378, 'Brest'),
(379, 'Bridgend'),
(380, 'Bridgeport'),
(381, 'Bridgetown'),
(382, 'Brighton'),
(383, 'Brisbane'),
(384, 'Bristol'),
(385, 'Brno'),
(386, 'Brownsville'),
(387, 'Brugge'),
(388, 'Brussels'),
(389, 'Bryansk'),
(390, 'Bucaramanga'),
(391, 'Bucharest'),
(392, 'Budapest'),
(393, 'Buea'),
(394, 'Buenaventura'),
(395, 'Buenos Aires'),
(396, 'Buffalo'),
(397, 'Bujumbura'),
(398, 'Bukavu'),
(399, 'Bukhoro'),
(400, 'Bukoba'),
(401, 'Bur Said'),
(402, 'Burdur'),
(403, 'Burgos'),
(404, 'Burlington'),
(405, 'Burnaby'),
(406, 'Bursa'),
(407, 'Bury'),
(408, 'Bushehr'),
(409, 'Butembo'),
(410, 'Buzau'),
(411, 'Bydgoszcz'),
(412, 'Bytom'),
(413, 'Cabimas'),
(414, 'Cabinda'),
(415, 'Cabo de Santo Agostinho'),
(416, 'Cabo Frio'),
(417, 'Cachoeiro de Itapemirim'),
(418, 'Cadiz'),
(419, 'Caen'),
(420, 'Caernarfon'),
(421, 'Cagayan de Oro'),
(422, 'Cagliari'),
(423, 'Cairo'),
(424, 'Cajamarca'),
(425, 'Calabar'),
(426, 'Calarasi'),
(427, 'Calcutta'),
(428, 'Calgary'),
(429, 'Cali'),
(430, 'Callao'),
(431, 'Cam Pha'),
(432, 'Camacari'),
(433, 'Camaguey'),
(434, 'Camaragibe'),
(435, 'Cambridge'),
(436, 'Campeche'),
(437, 'Campina Grande'),
(438, 'Campinas'),
(439, 'Campo Grande'),
(440, 'Campobasso'),
(441, 'Campos dos Goytacazes'),
(442, 'Can Tho'),
(443, 'Canakkale'),
(444, 'Canberra'),
(445, 'Cancun'),
(446, 'Cangzhou'),
(447, 'Cankiri'),
(448, 'Canoas'),
(449, 'Canterbury'),
(450, 'Cape Coast'),
(451, 'Cape Town'),
(452, 'Caracas'),
(453, 'Carapicuiba'),
(454, 'Cardiff'),
(455, 'Cariacica'),
(456, 'Carletonville'),
(457, 'Carlisle'),
(458, 'Carmarthen'),
(459, 'Carson City'),
(460, 'Cartagena'),
(461, 'Cartago'),
(462, 'Caruaru'),
(463, 'Casablanca'),
(464, 'Cascavel'),
(465, 'Castanhal'),
(466, 'Castellon de la Plana'),
(467, 'Castelo Branco'),
(468, 'Castries'),
(469, 'Catanduva'),
(470, 'Catania'),
(471, 'Catanzaro'),
(472, 'Catia La Mar'),
(473, 'Caucaia'),
(474, 'Caxias'),
(475, 'Caxias do Sul'),
(476, 'Caxito'),
(477, 'Cayenne'),
(478, 'Cebu'),
(479, 'Cedar Rapids'),
(480, 'Celaya'),
(481, 'Cerro de Pasco'),
(482, 'Ceske Budejovice'),
(483, 'Chachapoyas'),
(484, 'Chake Cahke'),
(485, 'Chalons en Champagne'),
(486, 'Chandigarh'),
(487, 'Chandler'),
(488, 'Changchun'),
(489, 'Changde'),
(490, 'Changhua'),
(491, 'Changsha'),
(492, 'Changshu'),
(493, 'Changzhi'),
(494, 'Changzhou'),
(495, 'Chaoxian'),
(496, 'Chaoyang'),
(497, 'Chaozhou'),
(498, 'Chapeco'),
(499, 'Charjew'),
(500, 'Charleroi'),
(501, 'Charleston'),
(502, 'Charlotte'),
(503, 'Charlotte Amalie'),
(504, 'Charlottetown'),
(505, 'Chattanooga'),
(506, 'Cheboksary'),
(507, 'Cheju'),
(508, 'Chelm'),
(509, 'Chelmsford'),
(510, 'Cheltenham'),
(511, 'Chelyabinsk'),
(512, 'Chemnitz'),
(513, 'Chengde'),
(514, 'Chengdu'),
(515, 'Cherepovets'),
(516, 'Cherkasy'),
(517, 'Cherkessk'),
(518, 'Chernihiv'),
(519, 'Chernivtsi'),
(520, 'Chesapeake'),
(521, 'Chester'),
(522, 'Chesterfield'),
(523, 'Chetumal'),
(524, 'Cheyenne'),
(525, 'Chiai'),
(526, 'Chiang Mai'),
(527, 'Chiba'),
(528, 'Chicago'),
(529, 'Chichester'),
(530, 'Chiclayo'),
(531, 'Chifeng'),
(532, 'Chihuahua'),
(533, 'Chilpancingo'),
(534, 'Chilung'),
(535, 'Chimbote'),
(536, 'Chimoio'),
(537, 'Chinandega'),
(538, 'Chincha Alta'),
(539, 'Chingola'),
(540, 'Chiniot'),
(541, 'Chinju'),
(542, 'Chipata'),
(543, 'Chirchiq'),
(544, 'Chisinau'),
(545, 'Chita'),
(546, 'Chitre'),
(547, 'Chittagong'),
(548, 'Choluteca'),
(549, 'Chongjin'),
(550, 'Chongju'),
(551, 'Chongqing'),
(552, 'Chonju'),
(553, 'Chorzow'),
(554, 'Christchurch'),
(555, 'Chula Vista'),
(556, 'Chunchon'),
(557, 'Chungho'),
(558, 'Chungli'),
(559, 'Chur'),
(560, 'Chuxian'),
(561, 'Ciechanow'),
(562, 'Ciego de Avila'),
(563, 'Cienaga'),
(564, 'Cienfuegos'),
(565, 'Cincinnati'),
(566, 'Cirebon'),
(567, 'Ciudad Apodaca'),
(568, 'Ciudad Bolivar'),
(569, 'Ciudad Guayana'),
(570, 'Ciudad Juarez'),
(571, 'Ciudad Madero'),
(572, 'Ciudad Obregon'),
(573, 'Ciudad Santa Catarina'),
(574, 'Ciudad Victoria'),
(575, 'Cixi'),
(576, 'Clearwater'),
(577, 'Clermont Ferrand'),
(578, 'Cleveland'),
(579, 'Cluj Napoca'),
(580, 'Coatzacoalcos'),
(581, 'Cochabamba'),
(582, 'Cochin'),
(583, 'Codo'),
(584, 'Coimbatore'),
(585, 'Coimbra'),
(586, 'Colatina'),
(587, 'Colchester'),
(588, 'Colima'),
(589, 'Colombo'),
(590, 'Colon'),
(591, 'Colorado Springs'),
(592, 'Columbia'),
(593, 'Columbus'),
(594, 'Colwyn Bay'),
(595, 'Comayagua'),
(596, 'Comilla'),
(597, 'Comodoro Rivadavia'),
(598, 'Conakry'),
(599, 'Concord'),
(600, 'Concordia'),
(601, 'Constanta'),
(602, 'Constantine'),
(603, 'Contagem'),
(604, 'Copenhagen'),
(605, 'Coral Springs'),
(606, 'Cordoba'),
(607, 'Coro'),
(608, 'Corona'),
(609, 'Corpus Christi'),
(610, 'Corrientes'),
(611, 'Corum'),
(612, 'Cosenza'),
(613, 'Costa Mesa'),
(614, 'Cotia'),
(615, 'Cottbus'),
(616, 'Coventry'),
(617, 'Craiova'),
(618, 'Crewe'),
(619, 'Criciuma'),
(620, 'Cuautla'),
(621, 'Cucuta'),
(622, 'Cuernavaca'),
(623, 'Cuiaba'),
(624, 'Culiacan'),
(625, 'Cumana'),
(626, 'Curitiba'),
(627, 'Cuttack'),
(628, 'Cuzco'),
(629, 'Cwmbran'),
(630, 'Czestochowa'),
(631, 'Da Nang'),
(632, 'Daan'),
(633, 'Dabrowa Gornicza'),
(634, 'Dahuk'),
(635, 'Dakar'),
(636, 'Dalian'),
(637, 'Dallas'),
(638, 'Daman'),
(639, 'Damanhur'),
(640, 'Damascus'),
(641, 'Dandong'),
(642, 'Danli'),
(643, 'Danyang'),
(644, 'Daqing'),
(645, 'Dar es Salaam'),
(646, 'Darlington'),
(647, 'Darmstadt'),
(648, 'Darwin'),
(649, 'Datong'),
(650, 'Davao'),
(651, 'David'),
(652, 'Daxian'),
(653, 'Dayton'),
(654, 'Deba Habe'),
(655, 'Debrecen'),
(656, 'Debrezit'),
(657, 'Dededo'),
(658, 'Delemont'),
(659, 'Delgado'),
(660, 'Denizli'),
(661, 'Denver'),
(662, 'Dera Ghazi Khan'),
(663, 'Derby'),
(664, 'Des Moines'),
(665, 'Dese'),
(666, 'Detroit'),
(667, 'Deva'),
(668, 'Deyang'),
(669, 'Dezful'),
(670, 'Dezhou'),
(671, 'Dhaka'),
(672, 'Diadema'),
(673, 'Dijon'),
(674, 'Dili'),
(675, 'Dimitrovgrad'),
(676, 'Dinajpur'),
(677, 'Diourbel'),
(678, 'Dire Dawa'),
(679, 'Dispur'),
(680, 'Divinopolis'),
(681, 'Diwaniyah'),
(682, 'Diyarbakir'),
(683, 'Djibouti'),
(684, 'Dniprodzerzhynsk'),
(685, 'Dnipropetrovsk'),
(686, 'Dodoma'),
(687, 'Doha'),
(688, 'Doncaster'),
(689, 'Donetsk'),
(690, 'Dongguan'),
(691, 'Dongtai'),
(692, 'Dongying'),
(693, 'Donostia'),
(694, 'Dorchester'),
(695, 'Dordrecht'),
(696, 'Dortmund'),
(697, 'Dosquebradas'),
(698, 'Douala'),
(699, 'Douglas'),
(700, 'Dourados'),
(701, 'Dover'),
(702, 'Drammen'),
(703, 'Dresden'),
(704, 'Drobeta Turnu Severin'),
(705, 'Dubai'),
(706, 'Dublin'),
(707, 'Dudley'),
(708, 'Duisburg'),
(709, 'Dukou'),
(710, 'Dumfries'),
(711, 'Dumyat'),
(712, 'Dundee'),
(713, 'Dunhua'),
(714, 'Duque de Caxias'),
(715, 'Durango'),
(716, 'Durban'),
(717, 'Durgapur'),
(718, 'Durham'),
(719, 'Durres'),
(720, 'Dushanbe'),
(721, 'Dusseldorf'),
(722, 'Duyun'),
(723, 'Dzerzhinsk'),
(724, 'Dzhambul'),
(725, 'East London'),
(726, 'East York'),
(727, 'Eastleigh'),
(728, 'Ebbw Vale'),
(729, 'Ebolowa'),
(730, 'Echeng'),
(731, 'Ede'),
(732, 'Edinburgh'),
(733, 'Edirne'),
(734, 'Edmonton'),
(735, 'Effon Alaiye'),
(736, 'Eger'),
(737, 'Eindhoven'),
(738, 'Eisenstadt'),
(739, 'Ekibastuz'),
(740, 'El Aaiun'),
(741, 'El Arish'),
(742, 'El Faiyum'),
(743, 'El Giza'),
(744, 'El Kharga'),
(745, 'El Mahalla el Kubra'),
(746, 'El Mansura'),
(747, 'El Minya'),
(748, 'El Monte'),
(749, 'El Paso'),
(750, 'El Porvenir'),
(751, 'El Progreso'),
(752, 'El Suweiz'),
(753, 'El Tur'),
(754, 'El Uqsur'),
(755, 'Elazig'),
(756, 'Elbasan'),
(757, 'Elblag'),
(758, 'Eldoret'),
(759, 'Elektrostal'),
(760, 'Elista'),
(761, 'Elizabeth'),
(762, 'Elmbridge'),
(763, 'Elx'),
(764, 'Embu'),
(765, 'Engels'),
(766, 'Enschede'),
(767, 'Ensenada'),
(768, 'Enugu'),
(769, 'Envigado'),
(770, 'Epping Forest'),
(771, 'Erfurt'),
(772, 'Erie'),
(773, 'Erlangen'),
(774, 'Ermoupoli'),
(775, 'Erzincan'),
(776, 'Erzurum'),
(777, 'Esbjerg'),
(778, 'Escondido'),
(779, 'Esfahan'),
(780, 'Eskisehir'),
(781, 'Espoo'),
(782, 'Essen'),
(783, 'Etobicoke'),
(784, 'Eugene'),
(785, 'Evansville'),
(786, 'Evora'),
(787, 'Exeter'),
(788, 'Falun'),
(789, 'Fareham'),
(790, 'Farghona'),
(791, 'Faridabad'),
(792, 'Faro'),
(793, 'Fatick'),
(794, 'Feira de Santana'),
(795, 'Fengcheng'),
(796, 'Fengshan'),
(797, 'Fengyuan'),
(798, 'Ferrara'),
(799, 'Ferraz de Vasconcelos'),
(800, 'Fes'),
(801, 'Fianarantsoa'),
(802, 'Firenze'),
(803, 'Flint'),
(804, 'Florencia'),
(805, 'Florianopolis'),
(806, 'Floridablanca'),
(807, 'Flying Fish Cove'),
(808, 'Focsani'),
(809, 'Foggia'),
(810, 'Fontana'),
(811, 'Forli'),
(812, 'Formosa'),
(813, 'Fort Collins'),
(814, 'Fort Lauderdale'),
(815, 'Fort Wayne'),
(816, 'Fort Worth'),
(817, 'Fort-de-France'),
(818, 'Fortaleza'),
(819, 'Foshan'),
(820, 'Foz do Iguacu'),
(821, 'Franca'),
(822, 'Francisco Morato'),
(823, 'Frankfort'),
(824, 'Frankfurt am Main'),
(825, 'Frauenfeld'),
(826, 'Fredericton'),
(827, 'Freetown'),
(828, 'Freiburg im Breisgau'),
(829, 'Fremont'),
(830, 'Fresno'),
(831, 'Fribourg'),
(832, 'Fuenlabrada'),
(833, 'Fukui'),
(834, 'Fukuoka'),
(835, 'Fukushima'),
(836, 'Fuling'),
(837, 'Fullerton'),
(838, 'Funafuti'),
(839, 'Funchal'),
(840, 'Furth'),
(841, 'Fushun'),
(842, 'Fuxin'),
(843, 'Fuyang'),
(844, 'Fuyu'),
(845, 'Fuzhou'),
(846, 'Gaborone'),
(847, 'Galati'),
(848, 'Gandhinagar'),
(849, 'Gangtok'),
(850, 'Ganzhou'),
(851, 'Garanhuns'),
(852, 'Garden Grove'),
(853, 'Garissa'),
(854, 'Garland'),
(855, 'Garoua'),
(856, 'Gary'),
(857, 'Gateshead'),
(858, 'Gauhati'),
(859, 'Gavle'),
(860, 'Gaza'),
(861, 'Gaziantep'),
(862, 'Gazipur'),
(863, 'Gdansk'),
(864, 'Gdynia'),
(865, 'Gebze'),
(866, 'Geelong'),
(867, 'Gejiu'),
(868, 'Geleen'),
(869, 'Gelsenkirchen'),
(870, 'General San Martin'),
(871, 'Geneva'),
(872, 'Genua'),
(873, 'George Town'),
(874, 'Georgetown'),
(875, 'Gera'),
(876, 'Getafe'),
(877, 'Ghaziabad'),
(878, 'Ghent'),
(879, 'Gibraltar'),
(880, 'Gifu'),
(881, 'Gijon'),
(882, 'Giresun'),
(883, 'Giurgiu'),
(884, 'Glarus'),
(885, 'Glasgow'),
(886, 'Glazov'),
(887, 'Glendale'),
(888, 'Glenrothes'),
(889, 'Gliwice'),
(890, 'Gloucester'),
(891, 'Goiania'),
(892, 'Gold Coast'),
(893, 'Goma'),
(894, 'Gomez Palacio'),
(895, 'Gonbad e Kavus'),
(896, 'Gonder'),
(897, 'Gongzhuling'),
(898, 'Gorakhpur'),
(899, 'Gorgan'),
(900, 'Gorno Altaysk'),
(901, 'Gorontalo'),
(902, 'Gorzow Wielkopolski'),
(903, 'Gorzow Wielkopolskie'),
(904, 'Goteborg'),
(905, 'Gottingen'),
(906, 'Governador Valadares'),
(907, 'Gracias'),
(908, 'Granada'),
(909, 'Grand Prairie'),
(910, 'Grand Rapids'),
(911, 'Grand Turk'),
(912, 'Gravatai'),
(913, 'Graz'),
(914, 'Green Bay'),
(915, 'Greensboro'),
(916, 'Grenoble'),
(917, 'Groningen'),
(918, 'Grozny'),
(919, 'Grudziadz'),
(920, 'Guacara'),
(921, 'Guadalajara'),
(922, 'Guadalupe'),
(923, 'Guanajuato'),
(924, 'Guanare'),
(925, 'Guangshui'),
(926, 'Guangyuan'),
(927, 'Guangzhou'),
(928, 'Guantanamo'),
(929, 'Guarapuava'),
(930, 'Guarda'),
(931, 'Guarenas'),
(932, 'Guaruja'),
(933, 'Guarulhos'),
(934, 'Guatemala City'),
(935, 'Guayaquil'),
(936, 'Guildford'),
(937, 'Guilin'),
(938, 'Guixian'),
(939, 'Guiyang'),
(940, 'Gujranwala'),
(941, 'Gujrat'),
(942, 'Guliston'),
(943, 'Gumushane'),
(944, 'Guntur'),
(945, 'Gusau'),
(946, 'Gwalior'),
(947, 'Gyor'),
(948, 'Haarlem'),
(949, 'Haeju'),
(950, 'Haemeenlinna'),
(951, 'Hafnarfjoerdur'),
(952, 'Hagen'),
(953, 'Haicheng'),
(954, 'Haifa'),
(955, 'Haikou'),
(956, 'Hailar'),
(957, 'Haining'),
(958, 'Haiphong'),
(959, 'Hakha'),
(960, 'Hakkari'),
(961, 'Hakodate'),
(962, 'Halifax'),
(963, 'Halle'),
(964, 'Halmstad'),
(965, 'Hamadan'),
(966, 'Hamar'),
(967, 'Hamburg'),
(968, 'Hamhung Hungnam'),
(969, 'Hami'),
(970, 'Hamilton'),
(971, 'Hamm'),
(972, 'Hammerfest'),
(973, 'Hampton'),
(974, 'Handan'),
(975, 'Hangzhou'),
(976, 'Hannover'),
(977, 'Hanoi'),
(978, 'Hanzhong'),
(979, 'Haora'),
(980, 'Harare'),
(981, 'Harbin'),
(982, 'Harer'),
(983, 'Harnosand'),
(984, 'Harrisburg'),
(985, 'Harrogate'),
(986, 'Hartford'),
(987, 'Hasselt'),
(988, 'Havana'),
(989, 'Havant'),
(990, 'Haverfordwest'),
(991, 'Hayward'),
(992, 'Hebi'),
(993, 'Heerlen'),
(994, 'Hefei'),
(995, 'Hegang'),
(996, 'Heidelberg'),
(997, 'Heilbronn'),
(998, 'Helena'),
(999, 'Helsingborg'),
(1000, 'Helsinki'),
(1001, 'Helwan'),
(1002, 'Henderson'),
(1003, 'Hengshui'),
(1004, 'Hengyang'),
(1005, 'Heredia'),
(1006, 'Herisau'),
(1007, 'Hermannsverk'),
(1008, 'Hermosillo'),
(1009, 'Herne'),
(1010, 'Heroica Nogales'),
(1011, 'Hertford'),
(1012, 'Heyuan'),
(1013, 'Heze'),
(1014, 'Hialeah'),
(1015, 'Hildesheim'),
(1016, 'Hilo'),
(1017, 'Hilversum'),
(1018, 'Hiroshima'),
(1019, 'Hobart'),
(1020, 'Hodmezovasarhely'),
(1021, 'Hohhot'),
(1022, 'Holguin'),
(1023, 'Hollywood'),
(1024, 'Homs'),
(1025, 'Hong Gai'),
(1026, 'Hong Kong'),
(1027, 'Honghu'),
(1028, 'Honiara'),
(1029, 'Honolulu'),
(1030, 'Horlivka'),
(1031, 'Horsham'),
(1032, 'Hortolandia'),
(1033, 'Hospitalet de Llobregat'),
(1034, 'Houston'),
(1035, 'Hpa an'),
(1036, 'Hradec Kralove'),
(1037, 'Hsinchu'),
(1038, 'Hsinchuang'),
(1039, 'Hsintien'),
(1040, 'Huadian'),
(1041, 'Huaian'),
(1042, 'Huaibei'),
(1043, 'Huaihua'),
(1044, 'Huainan'),
(1045, 'Huaiyin'),
(1046, 'Hualien'),
(1047, 'Huambo'),
(1048, 'Huancavelica'),
(1049, 'Huancayo'),
(1050, 'Huangshi'),
(1051, 'Huanuco'),
(1052, 'Huaraz'),
(1053, 'Hubli'),
(1054, 'Huddersfield'),
(1055, 'Hue'),
(1056, 'Huelva'),
(1057, 'Huichon'),
(1058, 'Huizhou'),
(1059, 'Hull'),
(1060, 'Hunjiang'),
(1061, 'Huntingdon'),
(1062, 'Huntington Beach'),
(1063, 'Huntsville'),
(1064, 'Hurghada'),
(1065, 'Huzhou'),
(1066, 'Hyderabad'),
(1067, 'Iasi'),
(1068, 'Ibadan'),
(1069, 'Ibague'),
(1070, 'Ibirite'),
(1071, 'Ica'),
(1072, 'Ife'),
(1073, 'Ijebu Ode'),
(1074, 'Ikare'),
(1075, 'Ikerre'),
(1076, 'Ikire'),
(1077, 'Ikirun'),
(1078, 'Ikorodu'),
(1079, 'Ila'),
(1080, 'Ilam'),
(1081, 'Ilawe Ekiti'),
(1082, 'Ilesha'),
(1083, 'Ilheus'),
(1084, 'Ilobu'),
(1085, 'Ilorin'),
(1086, 'Imperatriz'),
(1087, 'Imphal'),
(1088, 'Inchon'),
(1089, 'Indaiatuba'),
(1090, 'Independence'),
(1091, 'Indianapolis'),
(1092, 'Indore'),
(1093, 'Inglewood'),
(1094, 'Ingolstadt'),
(1095, 'Inhambane'),
(1096, 'Inisa'),
(1097, 'Innsbruck'),
(1098, 'Inverness'),
(1099, 'Ioannina'),
(1100, 'Ipatinga'),
(1101, 'Ipoh'),
(1102, 'Ipswich'),
(1103, 'Iquitos'),
(1104, 'Iraklion'),
(1105, 'Irapuato'),
(1106, 'Iringa'),
(1107, 'Irkutsk'),
(1108, 'Irvine'),
(1109, 'Irving'),
(1110, 'Iseyin'),
(1111, 'Iskenderun'),
(1112, 'Islamabad'),
(1113, 'Islamshahr'),
(1114, 'Ismailiya'),
(1115, 'Isparta'),
(1116, 'Istanbul'),
(1117, 'Itaborai'),
(1118, 'Itabuna'),
(1119, 'Itagui'),
(1120, 'Itaituba'),
(1121, 'Itajai'),
(1122, 'Itanagar'),
(1123, 'Itapecerica da Serra'),
(1124, 'Itapetininga'),
(1125, 'Itapevi'),
(1126, 'Itaquaquecetuba'),
(1127, 'Itu'),
(1128, 'Ivano Frankivsk'),
(1129, 'Ivanovo'),
(1130, 'Iwo'),
(1131, 'Izhevsk'),
(1132, 'Izmir'),
(1133, 'Izmit'),
(1134, 'Jabalpur'),
(1135, 'Jaboatao dos Guararapes'),
(1136, 'Jacarei'),
(1137, 'Jackson'),
(1138, 'Jacksonville'),
(1139, 'Jaen'),
(1140, 'Jaipur'),
(1141, 'Jakarta'),
(1142, 'Jalandhar'),
(1143, 'Jalapa'),
(1144, 'Jamalpur'),
(1145, 'Jambi'),
(1146, 'Jamestown'),
(1147, 'Jammu'),
(1148, 'Jamnagar'),
(1149, 'Jamshedpur'),
(1150, 'Jastrzebie Zdroj'),
(1151, 'Jau'),
(1152, 'Jeddah'),
(1153, 'Jefferson City'),
(1154, 'Jelenia Gora'),
(1155, 'Jena'),
(1156, 'Jequie'),
(1157, 'Jerez de la Frontera'),
(1158, 'Jersey City'),
(1159, 'Jerusalem'),
(1160, 'Jessore'),
(1161, 'Jhang'),
(1162, 'Jhansi'),
(1163, 'Jhelum'),
(1164, 'Jiamusi'),
(1165, 'Jiangmen'),
(1166, 'Jiangyin'),
(1167, 'Jiangyou'),
(1168, 'Jiaonan'),
(1169, 'Jiaoxian'),
(1170, 'Jiaozuo'),
(1171, 'Jiaxing'),
(1172, 'Jilin'),
(1173, 'Jima'),
(1174, 'Jinan'),
(1175, 'Jincheng'),
(1176, 'Jingdezhen'),
(1177, 'Jinhua'),
(1178, 'Jining'),
(1179, 'Jinxi'),
(1180, 'Jinzhou'),
(1181, 'Jiujiang'),
(1182, 'Jiutai'),
(1183, 'Jixi'),
(1184, 'Jizzakh'),
(1185, 'Joao Pessoa'),
(1186, 'Jodhpur'),
(1187, 'Joensuu'),
(1188, 'Johannesburg'),
(1189, 'Johor Baharu'),
(1190, 'Joinvile'),
(1191, 'Jokkmokk'),
(1192, 'Jonkoping'),
(1193, 'Jos'),
(1194, 'Juazeiro'),
(1195, 'Juazeiro do Norte'),
(1196, 'Juba'),
(1197, 'Juiz de Fora'),
(1198, 'Juliaca'),
(1199, 'Jundiai'),
(1200, 'Juneau'),
(1201, 'Jutigalpa'),
(1202, 'Jyvaeskylae'),
(1203, 'Kabul'),
(1204, 'Kabwe'),
(1205, 'Kaduna'),
(1206, 'Kaesong'),
(1207, 'Kafr el Dauwar'),
(1208, 'Kafr el Sheikh'),
(1209, 'Kagoshima'),
(1210, 'Kaifeng'),
(1211, 'Kaili'),
(1212, 'Kaiserslautern'),
(1213, 'Kakamega'),
(1214, 'Kalemie'),
(1215, 'Kaliningrad'),
(1216, 'Kalisz'),
(1217, 'Kalmar'),
(1218, 'Kalookan'),
(1219, 'Kaluga'),
(1220, 'Kalyan'),
(1221, 'Kamensk Uralskiy'),
(1222, 'Kampala'),
(1223, 'Kamyshin'),
(1224, 'Kananga'),
(1225, 'Kanazawa'),
(1226, 'Kangar'),
(1227, 'Kanggye'),
(1228, 'Kano'),
(1229, 'Kanpur'),
(1230, 'Kansas City'),
(1231, 'Kansk'),
(1232, 'Kaohsiung'),
(1233, 'Kaolack'),
(1234, 'Kaposvar'),
(1235, 'Karabuk'),
(1236, 'Karachi'),
(1237, 'Karaganda'),
(1238, 'Karaj'),
(1239, 'Karaman'),
(1240, 'Karaman Maras'),
(1241, 'Karamay'),
(1242, 'Karbala'),
(1243, 'Karlskrona'),
(1244, 'Karlsruhe'),
(1245, 'Karlstad'),
(1246, 'Kars'),
(1247, 'Kasama'),
(1248, 'Kashan'),
(1249, 'Kashi'),
(1250, 'Kassala'),
(1251, 'Kassel'),
(1252, 'Kastamonu'),
(1253, 'Kasur'),
(1254, 'Kathmandu'),
(1255, 'Katowice'),
(1256, 'Katsina'),
(1257, 'Kavalla'),
(1258, 'Kavaratti'),
(1259, 'Kawasaki'),
(1260, 'Kayseri'),
(1261, 'Kazan'),
(1262, 'Kecskemet'),
(1263, 'Kediri'),
(1264, 'Keflavik'),
(1265, 'Kelang'),
(1266, 'Kemerovo'),
(1267, 'Kenitra'),
(1268, 'Kericho'),
(1269, 'Kerman'),
(1270, 'Khabarovsk'),
(1271, 'Kharkiv'),
(1272, 'Khartoum'),
(1273, 'Khartoum North'),
(1274, 'Kherson'),
(1275, 'Khimki'),
(1276, 'Khmelnytskyy'),
(1277, 'Khomeynishahr'),
(1278, 'Khon Kaen'),
(1279, 'Khorramabad'),
(1280, 'Khorramshahr'),
(1281, 'Khorugh'),
(1282, 'Khouribga'),
(1283, 'Khujand'),
(1284, 'Khulna'),
(1285, 'Khvoy'),
(1286, 'Kiel'),
(1287, 'Kielce'),
(1288, 'Kiev'),
(1289, 'Kigali'),
(1290, 'Kigoma Ujiji'),
(1291, 'Kikwit'),
(1292, 'Kimberley'),
(1293, 'Kineshma'),
(1294, 'Kings Lynn'),
(1295, 'Kingston'),
(1296, 'Kingston upon Hull'),
(1297, 'Kingstown'),
(1298, 'Kinshasa'),
(1299, 'Kirikkale'),
(1300, 'Kirklareli'),
(1301, 'Kirklees'),
(1302, 'Kirkuk'),
(1303, 'Kirkwall'),
(1304, 'Kirov'),
(1305, 'Kirovohrad'),
(1306, 'Kirsehir'),
(1307, 'Kisangani'),
(1308, 'Kiselyovsk'),
(1309, 'Kisii'),
(1310, 'Kislovodsk'),
(1311, 'Kisumu'),
(1312, 'Kita Kyushu'),
(1313, 'Kitale'),
(1314, 'Kitchener'),
(1315, 'Kitwe'),
(1316, 'Klagenfurt'),
(1317, 'Knowsley'),
(1318, 'Knoxville'),
(1319, 'Koani'),
(1320, 'Kobe'),
(1321, 'Koblenz'),
(1322, 'Kocaeli'),
(1323, 'Kochi'),
(1324, 'Kofu'),
(1325, 'Kohima'),
(1326, 'Kokchetau'),
(1327, 'Kolda'),
(1328, 'Kolhapur'),
(1329, 'Koln'),
(1330, 'Kolomna'),
(1331, 'Kolonia'),
(1332, 'Kolpino'),
(1333, 'Kolwezi'),
(1334, 'Komotini'),
(1335, 'Komsomolsk na Amure'),
(1336, 'Konin'),
(1337, 'Konya'),
(1338, 'Korce'),
(1339, 'Korfu'),
(1340, 'Korla'),
(1341, 'Koror'),
(1342, 'Kostroma'),
(1343, 'Koszalin'),
(1344, 'Kota'),
(1345, 'Kota Baharu'),
(1346, 'Kota Kinabalu'),
(1347, 'Kotka'),
(1348, 'Kovrov'),
(1349, 'Kozani'),
(1350, 'Kozhikode'),
(1351, 'Krakow'),
(1352, 'Krasnodar'),
(1353, 'Krasnoyarsk'),
(1354, 'Krefeld'),
(1355, 'Kremenchuk'),
(1356, 'Kristiansand'),
(1357, 'Kristianstad'),
(1358, 'Krosno'),
(1359, 'Kryvyy Rih'),
(1360, 'Kuala Lumpur'),
(1361, 'Kuala Terengganu'),
(1362, 'Kuantan'),
(1363, 'Kuching'),
(1364, 'Kulob'),
(1365, 'Kumamoto'),
(1366, 'Kumasi'),
(1367, 'Kumo'),
(1368, 'Kunming'),
(1369, 'Kunsan'),
(1370, 'Kunshan'),
(1371, 'Kuopio'),
(1372, 'Kurgan'),
(1373, 'Kursk'),
(1374, 'Kusong'),
(1375, 'Kutahya'),
(1376, 'Kuwait'),
(1377, 'Kuznetsk'),
(1378, 'Kwangju'),
(1379, 'Kyoto'),
(1380, 'Kyzyl'),
(1381, 'La Ascuncion'),
(1382, 'La Ceiba'),
(1383, 'La Coruna'),
(1384, 'La Esperanza'),
(1385, 'La Laguna'),
(1386, 'La Matanza'),
(1387, 'La Palma'),
(1388, 'La Paz'),
(1389, 'La Plata'),
(1390, 'La Rioja'),
(1391, 'La Spezia'),
(1392, 'Labuan'),
(1393, 'Lafayette'),
(1394, 'Lafia'),
(1395, 'Lages'),
(1396, 'Lagos'),
(1397, 'Lahore'),
(1398, 'Lahore Cantonment'),
(1399, 'Lahti'),
(1400, 'Laiwu'),
(1401, 'Laiyang'),
(1402, 'Lakewood'),
(1403, 'Lamia'),
(1404, 'Lancaster'),
(1405, 'Lansing'),
(1406, 'Lanus'),
(1407, 'Lanzhou'),
(1408, 'Laohekou'),
(1409, 'Lappeenrenta'),
(1410, 'LAquila'),
(1411, 'Laredo'),
(1412, 'Larisa'),
(1413, 'Larkana'),
(1414, 'Las Palmas de Gran Canaria'),
(1415, 'Las Tablas'),
(1416, 'Las Vegas'),
(1417, 'Latina'),
(1418, 'Lausanne'),
(1419, 'Laval'),
(1420, 'Le Havre'),
(1421, 'Le Mans'),
(1422, 'Lecce'),
(1423, 'Leeds'),
(1424, 'Leeuwarden'),
(1425, 'Leganes'),
(1426, 'Legnica'),
(1427, 'Leichester'),
(1428, 'Leiden'),
(1429, 'Leipzig'),
(1430, 'Leiria'),
(1431, 'Leiyang'),
(1432, 'Lelystad'),
(1433, 'Lengshuijiang'),
(1434, 'Leninsk'),
(1435, 'Leninsk Kuznetskiy'),
(1436, 'Leon'),
(1437, 'Lerwick'),
(1438, 'Leshan'),
(1439, 'Leszno'),
(1440, 'Leticia'),
(1441, 'Leverkusen'),
(1442, 'Lewes'),
(1443, 'Lexington Fayette'),
(1444, 'Lhasa'),
(1445, 'Liancheng'),
(1446, 'Lianyungang'),
(1447, 'Liaocheng'),
(1448, 'Liaoyang'),
(1449, 'Liaoyuan'),
(1450, 'Liberec'),
(1451, 'Liberia'),
(1452, 'Libreville'),
(1453, 'Lichinga'),
(1454, 'Liege'),
(1455, 'Liestal'),
(1456, 'Likasi'),
(1457, 'Liling'),
(1458, 'Lille'),
(1459, 'Lillehammer'),
(1460, 'Lilongwe'),
(1461, 'Lima'),
(1462, 'Limeira'),
(1463, 'Limoges'),
(1464, 'Limon'),
(1465, 'Lincoln'),
(1466, 'Lindi'),
(1467, 'Linfen'),
(1468, 'Linhares'),
(1469, 'Linhe'),
(1470, 'Linkoping'),
(1471, 'Linqing'),
(1472, 'Linyi'),
(1473, 'Linz'),
(1474, 'Lipetsk'),
(1475, 'Lisbon'),
(1476, 'Little Rock'),
(1477, 'Liupanshui'),
(1478, 'Liuzhou'),
(1479, 'Liverpool'),
(1480, 'Livingstone'),
(1481, 'Livonia'),
(1482, 'Livorno'),
(1483, 'Liyang'),
(1484, 'Ljubljana'),
(1485, 'Llandrindod Wells'),
(1486, 'Llangefni'),
(1487, 'Lleida'),
(1488, 'Lodz'),
(1489, 'Logrono'),
(1490, 'Loikaw'),
(1491, 'Lomas de Zamoras'),
(1492, 'Lome'),
(1493, 'Lomza'),
(1494, 'London'),
(1495, 'Londrina'),
(1496, 'Long Beach'),
(1497, 'Long Xuyen'),
(1498, 'Longjing'),
(1499, 'Longkou'),
(1500, 'Longueuil'),
(1501, 'Longyan'),
(1502, 'Longyearbyen'),
(1503, 'Los Angeles'),
(1504, 'Los Mochis'),
(1505, 'Los Teques'),
(1506, 'Loudi'),
(1507, 'Louga'),
(1508, 'Louisville'),
(1509, 'Lowell'),
(1510, 'Luan'),
(1511, 'Luanda'),
(1512, 'Luanshya'),
(1513, 'Lubango'),
(1514, 'Lubbock'),
(1515, 'Lubeck'),
(1516, 'Lublin'),
(1517, 'Lubumbashi'),
(1518, 'Lucapa'),
(1519, 'Lucknow'),
(1520, 'Ludhiana'),
(1521, 'Ludwigshafen'),
(1522, 'Luena'),
(1523, 'Luhansk'),
(1524, 'Lulea'),
(1525, 'Luohe'),
(1526, 'Luoyang'),
(1527, 'Lusaka'),
(1528, 'Luton'),
(1529, 'Lutsk'),
(1530, 'Luxembourg'),
(1531, 'Luzern'),
(1532, 'Luzhou'),
(1533, 'Luziania'),
(1534, 'Lviv'),
(1535, 'Lyallpur'),
(1536, 'Lyon'),
(1537, 'Lyubertsy'),
(1538, 'Maanshan'),
(1539, 'Maastricht'),
(1540, 'Macae'),
(1541, 'Macapa'),
(1542, 'Macau'),
(1543, 'Macclesfield'),
(1544, 'Maceio'),
(1545, 'Machakos'),
(1546, 'Macon'),
(1547, 'Madison'),
(1548, 'Madiun'),
(1549, 'Madras'),
(1550, 'Madrid'),
(1551, 'Madurai'),
(1552, 'Maebashi'),
(1553, 'Magadan'),
(1554, 'Magdeburg'),
(1555, 'Mage'),
(1556, 'Magelang'),
(1557, 'Magnitogorsk'),
(1558, 'Magway'),
(1559, 'Maidstone'),
(1560, 'Maiduguri'),
(1561, 'Mainz'),
(1562, 'Majunga'),
(1563, 'Majuro'),
(1564, 'Makati'),
(1565, 'Makhachkala'),
(1566, 'Makiyivka'),
(1567, 'Makurdi'),
(1568, 'Malabo'),
(1569, 'Malaga'),
(1570, 'Malakal'),
(1571, 'Malambo'),
(1572, 'Malang'),
(1573, 'Malanje'),
(1574, 'Malatya'),
(1575, 'Malayer'),
(1576, 'Male'),
(1577, 'Malindi'),
(1578, 'Malmo'),
(1579, 'Mamoutzou'),
(1580, 'Manado'),
(1581, 'Managua'),
(1582, 'Manama'),
(1583, 'Manaus'),
(1584, 'Manchester'),
(1585, 'Mandalay'),
(1586, 'Mangangue'),
(1587, 'Manila'),
(1588, 'Manisa'),
(1589, 'Manizales'),
(1590, 'Mannheim'),
(1591, 'Mansa'),
(1592, 'Mansfield'),
(1593, 'Manzanillo'),
(1594, 'Manzhouli'),
(1595, 'Maoming'),
(1596, 'Maputo'),
(1597, 'Mar del Plata'),
(1598, 'Maraba'),
(1599, 'Maracaibo'),
(1600, 'Maracanau'),
(1601, 'Maracay'),
(1602, 'Maragheh'),
(1603, 'Mardan'),
(1604, 'Mardin'),
(1605, 'Marghilon'),
(1606, 'Mariehamn'),
(1607, 'Mariestad'),
(1608, 'Marigot'),
(1609, 'Marilia'),
(1610, 'Maringa'),
(1611, 'Mariupol'),
(1612, 'Markham'),
(1613, 'Maroua'),
(1614, 'Marrakech'),
(1615, 'Marsa Matruh'),
(1616, 'Marseille'),
(1617, 'Mary'),
(1618, 'Masan'),
(1619, 'Masaya'),
(1620, 'Maseru'),
(1621, 'Mashhad'),
(1622, 'Masjed e Soleyman'),
(1623, 'Mata-Utu'),
(1624, 'Matadi'),
(1625, 'Matala'),
(1626, 'Matamoros'),
(1627, 'Matanzas'),
(1628, 'Mataro'),
(1629, 'Matlock'),
(1630, 'Matsue'),
(1631, 'Matsuyama'),
(1632, 'Maturin'),
(1633, 'Maua'),
(1634, 'Maykop'),
(1635, 'Mazatlan'),
(1636, 'Mbabane'),
(1637, 'Mbandaka'),
(1638, 'Mbanza Congo'),
(1639, 'Mbeya'),
(1640, 'Mbuji Mayi'),
(1641, 'McAllen'),
(1642, 'Medan'),
(1643, 'Medellin'),
(1644, 'Meerut'),
(1645, 'Mehrshahr'),
(1646, 'Meihekou'),
(1647, 'Meixian'),
(1648, 'Mejicanos'),
(1649, 'Mekele'),
(1650, 'Meknes'),
(1651, 'Melaka'),
(1652, 'Melbourne'),
(1653, 'Melekeok'),
(1654, 'Memphis'),
(1655, 'Mendoza'),
(1656, 'Menongue'),
(1657, 'Merida'),
(1658, 'Mersin'),
(1659, 'Merthyr Tydfil'),
(1660, 'Meru'),
(1661, 'Mesa'),
(1662, 'Mesquite'),
(1663, 'Messina'),
(1664, 'Metz'),
(1665, 'Mexicali'),
(1666, 'Mexico City'),
(1667, 'Mezhdurechensk'),
(1668, 'Miami'),
(1669, 'Mianyang'),
(1670, 'Miass'),
(1671, 'Michurinsk'),
(1672, 'Middelburg'),
(1673, 'Middlesbrough'),
(1674, 'Miercurea Ciuc'),
(1675, 'Mikkeli'),
(1676, 'Milan'),
(1677, 'Milton Keynes'),
(1678, 'Milwaukee'),
(1679, 'Minatitlan'),
(1680, 'Minna'),
(1681, 'Minneapolis'),
(1682, 'Minsk'),
(1683, 'Mirpur Khas'),
(1684, 'Mishan'),
(1685, 'Miskolc'),
(1686, 'Mississauga'),
(1687, 'Mito'),
(1688, 'Mitu'),
(1689, 'Mixco'),
(1690, 'Miyazaki'),
(1691, 'Mkokotoni'),
(1692, 'Mmabatho'),
(1693, 'Mobile'),
(1694, 'Mocoa'),
(1695, 'Modena'),
(1696, 'Modesto'),
(1697, 'Moers'),
(1698, 'Mogadishu'),
(1699, 'Moji das Cruzes'),
(1700, 'Moji Guacu'),
(1701, 'Mokpo'),
(1702, 'Mold'),
(1703, 'Molde'),
(1704, 'Mombasa'),
(1705, 'Monaco'),
(1706, 'Monchengladbach'),
(1707, 'Monclova'),
(1708, 'Mongu'),
(1709, 'Monrovia'),
(1710, 'Mons'),
(1711, 'Monteria'),
(1712, 'Monterrey'),
(1713, 'Montes Claros'),
(1714, 'Montevideo'),
(1715, 'Montgomery'),
(1716, 'Montpelier'),
(1717, 'Montpellier'),
(1718, 'Montreal'),
(1719, 'Monywa'),
(1720, 'Monza'),
(1721, 'Moquegua'),
(1722, 'Moradabad'),
(1723, 'Morelia'),
(1724, 'Moreno Valley'),
(1725, 'Morioka'),
(1726, 'Morogoro'),
(1727, 'Moron'),
(1728, 'Moroni'),
(1729, 'Moscow'),
(1730, 'Moshi'),
(1731, 'Moss'),
(1732, 'Mossoro'),
(1733, 'Mostaganem'),
(1734, 'Mostoles'),
(1735, 'Mosul'),
(1736, 'Moulmein'),
(1737, 'Moyobamba'),
(1738, 'Mtwara Mikandani'),
(1739, 'Mudanjiang'),
(1740, 'Mufulira'),
(1741, 'Mugla'),
(1742, 'Mulheim an der Ruhr'),
(1743, 'Mulhouse'),
(1744, 'Multan'),
(1745, 'Mumbai'),
(1746, 'Munich'),
(1747, 'Munster'),
(1748, 'Murcia'),
(1749, 'Murmansk'),
(1750, 'Murom'),
(1751, 'Mus'),
(1752, 'Muscat'),
(1753, 'Mushin'),
(1754, 'Musoma'),
(1755, 'Mwanza'),
(1756, 'Mwene Ditu'),
(1757, 'Myitkyina'),
(1758, 'Mykolayiv'),
(1759, 'Mymensingh'),
(1760, 'Mysore'),
(1761, 'Mytilini'),
(1762, 'Mytishchi'),
(1763, 'Naberezhnye Chelny'),
(1764, 'Nablus'),
(1765, 'Nacala'),
(1766, 'Nacaome'),
(1767, 'Nagano'),
(1768, 'Nagasaki'),
(1769, 'Nagoya'),
(1770, 'Nagpur'),
(1771, 'Naha'),
(1772, 'Nairobi'),
(1773, 'Najafabad'),
(1774, 'Nakhodka'),
(1775, 'Nakhon Ratchasima'),
(1776, 'Nakhon Sawan'),
(1777, 'Nakhon si Thammarat'),
(1778, 'Nakuru'),
(1779, 'Nalchik'),
(1780, 'Nam Dinh'),
(1781, 'Namangan'),
(1782, 'Namibe'),
(1783, 'Nampo'),
(1784, 'Nampula'),
(1785, 'Namur'),
(1786, 'Nanchang'),
(1787, 'Nanchong'),
(1788, 'Nancy'),
(1789, 'Nanjing'),
(1790, 'Nanning'),
(1791, 'Nanping'),
(1792, 'Nantes'),
(1793, 'Nantong'),
(1794, 'Nanyang'),
(1795, 'Naogaon'),
(1796, 'Naperville'),
(1797, 'Napoli'),
(1798, 'Nara'),
(1799, 'Narayanganj'),
(1800, 'Narsinghdi'),
(1801, 'Narvik'),
(1802, 'Nashville'),
(1803, 'Nashville Davidson'),
(1804, 'Nasik'),
(1805, 'Nassau'),
(1806, 'Natal'),
(1807, 'Nawabganj'),
(1808, 'Nawabshah'),
(1809, 'Nawoiy'),
(1810, 'Nazareth'),
(1811, 'Nazran'),
(1812, 'Nazret'),
(1813, 'Ndalatando'),
(1814, 'NDjamena'),
(1815, 'Ndola'),
(1816, 'Nebitdag'),
(1817, 'Neftekamsk'),
(1818, 'Neijiang'),
(1819, 'Neiva'),
(1820, 'Nelspruit'),
(1821, 'Nepean'),
(1822, 'Neuchatel'),
(1823, 'Neuquen'),
(1824, 'Neuss'),
(1825, 'Nevinnomyssk'),
(1826, 'Nevsehir'),
(1827, 'New Bombay'),
(1828, 'New Delhi'),
(1829, 'New Haven'),
(1830, 'New Orleans'),
(1831, 'New York'),
(1832, 'Newark'),
(1833, 'Newark on Trent'),
(1834, 'Newbury'),
(1835, 'Newcastle'),
(1836, 'Newcastle under Lyme'),
(1837, 'Newcastle upon Tyne'),
(1838, 'Newport'),
(1839, 'Newport News'),
(1840, 'Newtown St. Boswells'),
(1841, 'Neyshabur'),
(1842, 'Nezahualcoyotl'),
(1843, 'Ngaoundere'),
(1844, 'Ngiva'),
(1845, 'Nha Trang'),
(1846, 'Niamey'),
(1847, 'Nice'),
(1848, 'Nicosia'),
(1849, 'Nigde'),
(1850, 'Niigata'),
(1851, 'Nijmegen'),
(1852, 'Nilopolis'),
(1853, 'Nimes'),
(1854, 'Ningbo'),
(1855, 'Niteroi'),
(1856, 'Nizhnekamsk'),
(1857, 'Nizhnevartovsk'),
(1858, 'Nizhniy Novgorod'),
(1859, 'Nizhniy Tagil'),
(1860, 'Noginsk'),
(1861, 'Nonthaburi'),
(1862, 'Norfolk'),
(1863, 'Norilsk'),
(1864, 'Norrkoping'),
(1865, 'North York'),
(1866, 'Northallerton'),
(1867, 'Northampton'),
(1868, 'Norwalk'),
(1869, 'Norwich'),
(1870, 'Nossa Senhora do Socorro'),
(1871, 'Nottingham'),
(1872, 'Nouakchott'),
(1873, 'Noumea'),
(1874, 'Nova Friburgo'),
(1875, 'Novara'),
(1876, 'Novgorod'),
(1877, 'Novo Hamburgo'),
(1878, 'Novo Iguacu'),
(1879, 'Novocheboksarsk'),
(1880, 'Novocherkassk'),
(1881, 'Novokuybyshevsk'),
(1882, 'Novokuznetsk'),
(1883, 'Novomoskovsk'),
(1884, 'Novorossiysk'),
(1885, 'Novoshakhtinsk'),
(1886, 'Novosibirsk'),
(1887, 'Novotroitsk'),
(1888, 'Nowy Sacz'),
(1889, 'Nueva Gerona'),
(1890, 'Nueva San Salvador'),
(1891, 'Nuevo Laredo'),
(1892, 'Nukualofa'),
(1893, 'Nukus'),
(1894, 'Nuneaton'),
(1895, 'Nurnberg'),
(1896, 'Nuuk'),
(1897, 'Nyala'),
(1898, 'Nyeri'),
(1899, 'Nyiregyhaza'),
(1900, 'Nykoping'),
(1901, 'Oakland'),
(1902, 'Oaxaca'),
(1903, 'Oberhausen'),
(1904, 'Obninsk'),
(1905, 'Oceanside'),
(1906, 'Ocotepeque'),
(1907, 'Odense'),
(1908, 'Odesa'),
(1909, 'Odintsovo'),
(1910, 'Offa'),
(1911, 'Offenbach am Main'),
(1912, 'Ogbomosho'),
(1913, 'Oita'),
(1914, 'Oka'),
(1915, 'Okara'),
(1916, 'Okayama'),
(1917, 'Okhotsk'),
(1918, 'Oklahoma City'),
(1919, 'Oktyabrsky'),
(1920, 'Olanchito'),
(1921, 'Oldenburg'),
(1922, 'Oldham'),
(1923, 'Olinda'),
(1924, 'Olmaliq'),
(1925, 'Olomouc'),
(1926, 'Olsztyn'),
(1927, 'Olympia'),
(1928, 'Omaha'),
(1929, 'Omdurman'),
(1930, 'Omsk'),
(1931, 'Ondo'),
(1932, 'Onitsha'),
(1933, 'Ontario'),
(1934, 'Opole'),
(1935, 'Oradea'),
(1936, 'Oral'),
(1937, 'Oran'),
(1938, 'Orange'),
(1939, 'Oranjestad'),
(1940, 'Ordu'),
(1941, 'Orebro'),
(1942, 'Orekhovo Zuyevo'),
(1943, 'Orel'),
(1944, 'Orenburg'),
(1945, 'Orense'),
(1946, 'Orizaba'),
(1947, 'Orlando'),
(1948, 'Orleans'),
(1949, 'Orsk'),
(1950, 'Orumiyeh'),
(1951, 'Osaka'),
(1952, 'Osasco'),
(1953, 'Oshawa'),
(1954, 'Oshogbo'),
(1955, 'Oskemen'),
(1956, 'Oslo'),
(1957, 'Osmaniye'),
(1958, 'Osnabruck'),
(1959, 'Ostersund'),
(1960, 'Ostrava'),
(1961, 'Ostroleka'),
(1962, 'Otsu'),
(1963, 'Ottawa'),
(1964, 'Ouagadougou'),
(1965, 'Oujda'),
(1966, 'Oulu'),
(1967, 'Overland Park'),
(1968, 'Oviedo'),
(1969, 'Owo'),
(1970, 'Oxford'),
(1971, 'Oxnard'),
(1972, 'Oyo'),
(1973, 'Pabna'),
(1974, 'Pachuca'),
(1975, 'Pachuca de Soto'),
(1976, 'Padang'),
(1977, 'Paderborn'),
(1978, 'Padova'),
(1979, 'Pago Pago'),
(1980, 'Palangkaraya'),
(1981, 'Palembang'),
(1982, 'Palermo'),
(1983, 'Palikir'),
(1984, 'Palma de Mallorca'),
(1985, 'Palmas'),
(1986, 'Palmdale'),
(1987, 'Palmira'),
(1988, 'Pamplona'),
(1989, 'Panaji'),
(1990, 'Panama City'),
(1991, 'Panchiao'),
(1992, 'Pangkal Pinang'),
(1993, 'Panshan'),
(1994, 'Papeete'),
(1995, 'Paramaribo'),
(1996, 'Parana'),
(1997, 'Paranagua'),
(1998, 'Pardubice'),
(1999, 'Pare Pare'),
(2000, 'Paris'),
(2001, 'Parma'),
(2002, 'Parnaiba'),
(2003, 'Pasadena'),
(2004, 'Pasay'),
(2005, 'Pasig'),
(2006, 'Passo Fundo'),
(2007, 'Pasto'),
(2008, 'Pasuruan'),
(2009, 'Paterson'),
(2010, 'Pathein'),
(2011, 'Patna'),
(2012, 'Patos de Minas'),
(2013, 'Patrai'),
(2014, 'Paulista'),
(2015, 'Pavlodar'),
(2016, 'Pecs'),
(2017, 'Pekalongan'),
(2018, 'Pekan Baru'),
(2019, 'Pelotas'),
(2020, 'Pematang Siantar'),
(2021, 'Pemba'),
(2022, 'Pembroke Pines'),
(2023, 'Penang'),
(2024, 'Penonome'),
(2025, 'Penza'),
(2026, 'Peoria'),
(2027, 'Pereira'),
(2028, 'Perm'),
(2029, 'Perpignan'),
(2030, 'Perth'),
(2031, 'Perugia'),
(2032, 'Pervouralsk'),
(2033, 'Pescara'),
(2034, 'Peshawar'),
(2035, 'Petaling Jaya'),
(2036, 'Petare'),
(2037, 'Peterborough'),
(2038, 'Petrolina'),
(2039, 'Petropavl'),
(2040, 'Petropavlovsk Kamchatsky'),
(2041, 'Petropolis'),
(2042, 'Petrozavodsk'),
(2043, 'Pforzheim'),
(2044, 'Philadelphia'),
(2045, 'Phnom Penh'),
(2046, 'Phoenix'),
(2047, 'Piacenza'),
(2048, 'Piatra Neamt'),
(2049, 'Pierre'),
(2050, 'Pietermaritzburg'),
(2051, 'Pietersburg'),
(2052, 'Pila'),
(2053, 'Pimpri Chinchwad'),
(2054, 'Pinar del Rio'),
(2055, 'Pindamonhangaba'),
(2056, 'Pingdingshan'),
(2057, 'Pingdu'),
(2058, 'Pingtung'),
(2059, 'Pingxiang'),
(2060, 'Piotrkow Trybunalski'),
(2061, 'Piracicaba'),
(2062, 'Piraeus'),
(2063, 'Pisa'),
(2064, 'Pitesti'),
(2065, 'Pittsburgh'),
(2066, 'Piura'),
(2067, 'Plano'),
(2068, 'Plock'),
(2069, 'Ploiesti'),
(2070, 'Plymouth'),
(2071, 'Plzen'),
(2072, 'Pocos de Caldas'),
(2073, 'Podgorica'),
(2074, 'Podolsk'),
(2075, 'Poitiers'),
(2076, 'Poltava'),
(2077, 'Pomona'),
(2078, 'Pondicherry'),
(2079, 'Ponta Delgada'),
(2080, 'Ponta Grossa'),
(2081, 'Pontianak'),
(2082, 'Pontypool'),
(2083, 'Poole'),
(2084, 'Popayan'),
(2085, 'Pori'),
(2086, 'Port Blair'),
(2087, 'Port Elizabeth'),
(2088, 'Port Harcourt'),
(2089, 'Port Louis'),
(2090, 'Port Moresby'),
(2091, 'Port Sudan'),
(2092, 'Port Talbot'),
(2093, 'Port-au-Prince'),
(2094, 'Port-of-Spain'),
(2095, 'Port-Vila'),
(2096, 'Portalegre'),
(2097, 'Portland'),
(2098, 'Porto'),
(2099, 'Porto Alegre'),
(2100, 'Porto Velho'),
(2101, 'Porto-Novo'),
(2102, 'Portsmouth'),
(2103, 'Posadas'),
(2104, 'Potenza'),
(2105, 'Potsdam'),
(2106, 'Poza Rica'),
(2107, 'Poznan'),
(2108, 'Prague'),
(2109, 'Praia'),
(2110, 'Praia Grande'),
(2111, 'Prato'),
(2112, 'Presidente Prudente'),
(2113, 'Preston'),
(2114, 'Pretoria'),
(2115, 'Pristina'),
(2116, 'Probolinggo'),
(2117, 'Prokopyevsk'),
(2118, 'Providence'),
(2119, 'Przemysl'),
(2120, 'Pskov'),
(2121, 'Pucallpa'),
(2122, 'Puebla'),
(2123, 'Puerto Ayacucho'),
(2124, 'Puerto Cabello'),
(2125, 'Puerto Carreno'),
(2126, 'Puerto Cortes'),
(2127, 'Puerto Inirida'),
(2128, 'Puerto La Cruz'),
(2129, 'Puerto Lempira'),
(2130, 'Puerto Maldonado'),
(2131, 'Pune'),
(2132, 'Puno'),
(2133, 'Puntarenas'),
(2134, 'Puqi'),
(2135, 'Pusan'),
(2136, 'Puyang'),
(2137, 'Pyatigorsk'),
(2138, 'Pyongyang'),
(2139, 'Qaemshahr'),
(2140, 'Qarshi'),
(2141, 'Qazvin'),
(2142, 'Qena'),
(2143, 'Qianjiang'),
(2144, 'Qingdao'),
(2145, 'Qinhuangdao'),
(2146, 'Qinzhou'),
(2147, 'Qiqihar'),
(2148, 'Qitaihe'),
(2149, 'Qom'),
(2150, 'Qostanay'),
(2151, 'Quanzhou'),
(2152, 'Quebec'),
(2153, 'Queimados'),
(2154, 'Quelimane'),
(2155, 'Queretaro'),
(2156, 'Quetta'),
(2157, 'Quezon'),
(2158, 'Qui Nhon'),
(2159, 'Quibdo'),
(2160, 'Quilmes'),
(2161, 'Quito'),
(2162, 'Qujing'),
(2163, 'Quqon'),
(2164, 'Qurghonteppa'),
(2165, 'Quzhou'),
(2166, 'Qyzylorda'),
(2167, 'Rabat'),
(2168, 'Radom'),
(2169, 'Rahim Yar Khan'),
(2170, 'Raipur'),
(2171, 'Rajahmundry'),
(2172, 'Rajaishahr'),
(2173, 'Rajkot'),
(2174, 'Rajshahi'),
(2175, 'Raleigh'),
(2176, 'Ramla'),
(2177, 'Ranchi'),
(2178, 'Rancho Cucamonga'),
(2179, 'Randers'),
(2180, 'Rangoon'),
(2181, 'Rangpur'),
(2182, 'Rasht'),
(2183, 'Ravenna'),
(2184, 'Rawalpindi'),
(2185, 'Rawson'),
(2186, 'Rayyan'),
(2187, 'Reading'),
(2188, 'Recife'),
(2189, 'Recklinghausen'),
(2190, 'Regensburg'),
(2191, 'Reggio di Calabria'),
(2192, 'Reggio nellEmilia'),
(2193, 'Regina'),
(2194, 'Reigate'),
(2195, 'Reims'),
(2196, 'Remscheid'),
(2197, 'Renfrew'),
(2198, 'Rennes'),
(2199, 'Reno'),
(2200, 'Renqiu'),
(2201, 'Resistencia'),
(2202, 'Resita'),
(2203, 'Reutlingen'),
(2204, 'Reykjavik'),
(2205, 'Reynosa'),
(2206, 'Rhondda'),
(2207, 'Rhymney Valley'),
(2208, 'Ribeirao das Neves'),
(2209, 'Ribeirao Pires'),
(2210, 'Ribeirao Preto'),
(2211, 'Richmond'),
(2212, 'Riga'),
(2213, 'Rimini'),
(2214, 'Rimnicu Vilcea'),
(2215, 'Rio Branco'),
(2216, 'Rio Claro'),
(2217, 'Rio Cuarto'),
(2218, 'Rio de Janeiro'),
(2219, 'Rio Gallegos'),
(2220, 'Rio Grande'),
(2221, 'Rio Verde'),
(2222, 'Riohacha'),
(2223, 'Riverside'),
(2224, 'Rivne'),
(2225, 'Riyadh'),
(2226, 'Rize'),
(2227, 'Rizhao'),
(2228, 'Road Town'),
(2229, 'Roatan'),
(2230, 'Rochdale'),
(2231, 'Rochester'),
(2232, 'Rochester upon Medway'),
(2233, 'Rockford'),
(2234, 'Rome'),
(2235, 'Rondonopolis'),
(2236, 'Rosario'),
(2237, 'Roseau'),
(2238, 'Rostock'),
(2239, 'Rostov na Donu'),
(2240, 'Rostov no Donu'),
(2241, 'Rotherham'),
(2242, 'Rotterdam'),
(2243, 'Rouen'),
(2244, 'Rovaniemi'),
(2245, 'Rubtsovsk'),
(2246, 'Ruda Slaska'),
(2247, 'Rudny'),
(2248, 'Ruian'),
(2249, 'Ruthin'),
(2250, 'Ryazan'),
(2251, 'Rybinsk'),
(2252, 'Rybnik'),
(2253, 'Rzeszow'),
(2254, 's Gravenhage'),
(2255, 's Hertogenbosch'),
(2256, 'Saarbrucken'),
(2257, 'Sabadell'),
(2258, 'Sabara'),
(2259, 'Sabzevar'),
(2260, 'Sacramento'),
(2261, 'Safi'),
(2262, 'Saga'),
(2263, 'Sagaing'),
(2264, 'Saharanpur'),
(2265, 'Sahiwal'),
(2266, 'Saidpur'),
(2267, 'Saigon'),
(2268, 'Saint Albans'),
(2269, 'Saint Catharines'),
(2270, 'Saint Etienne'),
(2271, 'Saint Georges'),
(2272, 'Saint Helens'),
(2273, 'Saint Helier'),
(2274, 'Saint Johns'),
(2275, 'Saint Louis'),
(2276, 'Saint Peter Port'),
(2277, 'Saint-Denis'),
(2278, 'Saint-Pierre'),
(2279, 'Saipan'),
(2280, 'Sakarya'),
(2281, 'Salamanca'),
(2282, 'Salavat'),
(2283, 'Salem'),
(2284, 'Salerno'),
(2285, 'Salford'),
(2286, 'Salgotarjan'),
(2287, 'Salinas'),
(2288, 'Salisbury'),
(2289, 'Salt Lake City'),
(2290, 'Salta'),
(2291, 'Saltillo'),
(2292, 'Salvador'),
(2293, 'Salzburg'),
(2294, 'Salzgitter'),
(2295, 'Samara'),
(2296, 'Samarinda'),
(2297, 'Samarqand'),
(2298, 'Samarra'),
(2299, 'Samsun'),
(2300, 'San Andres'),
(2301, 'San Antonio'),
(2302, 'San Bernardino'),
(2303, 'San Carlos'),
(2304, 'San Cristobal'),
(2305, 'San Diego'),
(2306, 'San Felipe'),
(2307, 'San Fernando'),
(2308, 'San Fernando del Valle de Catamarca'),
(2309, 'San Francisco'),
(2310, 'San Isidro'),
(2311, 'San Jose'),
(2312, 'San Jose del Guaviare'),
(2313, 'San Juan'),
(2314, 'San Luis'),
(2315, 'San Luis Potosi'),
(2316, 'San Marino'),
(2317, 'San Miguel de Tucuman'),
(2318, 'San Miguelito'),
(2319, 'San Nicolas de los Arroyos'),
(2320, 'San Nicolas de los Garza'),
(2321, 'San Pedro Garza Garcia'),
(2322, 'San Pedro Sula'),
(2323, 'San Salvador'),
(2324, 'San Salvador de Jujuy'),
(2325, 'Sanaa'),
(2326, 'Sanandaj'),
(2327, 'Sanchuung'),
(2328, 'Sancti Spiritus'),
(2329, 'Sandakan'),
(2330, 'Sandwell'),
(2331, 'Sankt Gallen'),
(2332, 'Sankt Peterburg'),
(2333, 'Sanmenxia'),
(2334, 'Sanming'),
(2335, 'Santa Ana'),
(2336, 'Santa Barbara'),
(2337, 'Santa Barbara dOeste'),
(2338, 'Santa Clara'),
(2339, 'Santa Clarita'),
(2340, 'Santa Coloma de Gramanet'),
(2341, 'Santa Cruz de Tenerife'),
(2342, 'Santa Cruz do Sul'),
(2343, 'Santa Fe'),
(2344, 'Santa Luzia'),
(2345, 'Santa Maria'),
(2346, 'Santa Marta'),
(2347, 'Santa Rita'),
(2348, 'Santa Rosa'),
(2349, 'Santa Rosa de Copan'),
(2350, 'Santander'),
(2351, 'Santarem'),
(2352, 'Santiago'),
(2353, 'Santiago de Compostella'),
(2354, 'Santiago de Cuba'),
(2355, 'Santiago del Estero'),
(2356, 'Santiago del Estero La Banda'),
(2357, 'Santo Andre'),
(2358, 'Santo Domingo'),
(2359, 'Santos'),
(2360, 'Sanya'),
(2361, 'Sao Bernardo do Campo'),
(2362, 'Sao Caetano do Sul'),
(2363, 'Sao Carlos'),
(2364, 'Sao Goncalo'),
(2365, 'Sao Joao de Meriti'),
(2366, 'Sao Jose'),
(2367, 'Sao Jose do Rio Preto'),
(2368, 'Sao Jose dos Campos'),
(2369, 'Sao Jose dos Pinhais'),
(2370, 'Sao Leopoldo'),
(2371, 'Sao Luis'),
(2372, 'Sao Paulo'),
(2373, 'Sao Tome'),
(2374, 'Sao Vicente'),
(2375, 'Sapele'),
(2376, 'Sapporo'),
(2377, 'Sapucaia do Sul'),
(2378, 'Saraburi'),
(2379, 'Sarajevo'),
(2380, 'Saransk'),
(2381, 'Sarapul'),
(2382, 'Saratov'),
(2383, 'Sargodha'),
(2384, 'Sari'),
(2385, 'Sarnen'),
(2386, 'Saskatoon'),
(2387, 'Sassari'),
(2388, 'Satu Mare'),
(2389, 'Saurimo'),
(2390, 'Savannah'),
(2391, 'Savar'),
(2392, 'Scarborough'),
(2393, 'Schaffhausen'),
(2394, 'Schwerin'),
(2395, 'Schwyz'),
(2396, 'Scottsdale'),
(2397, 'Seattle'),
(2398, 'Sefton'),
(2399, 'Sekondi'),
(2400, 'Selayang Baru'),
(2401, 'Semarang'),
(2402, 'Semey'),
(2403, 'Semnan'),
(2404, 'Sendai'),
(2405, 'Seoul'),
(2406, 'Seremban'),
(2407, 'Serov'),
(2408, 'Serpukhov'),
(2409, 'Serra'),
(2410, 'Sete Lagoas'),
(2411, 'Setif'),
(2412, 'Setubal'),
(2413, 'Sevastopol'),
(2414, 'Sevenoaks'),
(2415, 'Severodvinsk'),
(2416, 'Seversk'),
(2417, 'Sevilla'),
(2418, 'Sfintu Gheorghe'),
(2419, 'Shagamu'),
(2420, 'Shah Alam'),
(2421, 'Shahr e Kord'),
(2422, 'Shakhty'),
(2423, 'Shaki'),
(2424, 'Shanghai'),
(2425, 'Shangqiu'),
(2426, 'Shangrao'),
(2427, 'Shangzhi'),
(2428, 'Shantou'),
(2429, 'Shanwei'),
(2430, 'Shaoguan'),
(2431, 'Shaoxing'),
(2432, 'Shaoyang'),
(2433, 'Sharjah'),
(2434, 'Shashi'),
(2435, 'Shchyolkovo'),
(2436, 'Sheffield'),
(2437, 'Sheikhupura'),
(2438, 'Shenyang'),
(2439, 'Shenzhen'),
(2440, 'Shibin el Kom'),
(2441, 'Shihezi'),
(2442, 'Shijiazhuang'),
(2443, 'Shillong'),
(2444, 'Shinyanga'),
(2445, 'Shiraz'),
(2446, 'Shishou'),
(2447, 'Shiyan'),
(2448, 'Shizuishan'),
(2449, 'Shizuoka'),
(2450, 'Shkoder'),
(2451, 'Sholapur'),
(2452, 'Shomolu'),
(2453, 'Shreveport'),
(2454, 'Shrewsbury'),
(2455, 'Shuangcheng'),
(2456, 'Shuangyashan'),
(2457, 'Shubra el Kheima'),
(2458, 'Shymkent'),
(2459, 'Sialkot'),
(2460, 'Sibiu'),
(2461, 'Sibu'),
(2462, 'Sidi bel Abbes'),
(2463, 'Siedlce'),
(2464, 'Siegen'),
(2465, 'Sieradz'),
(2466, 'Siguatepeque'),
(2467, 'Siirt'),
(2468, 'Silvassa'),
(2469, 'Simbirsk'),
(2470, 'Simferopol'),
(2471, 'Simi Valley'),
(2472, 'Simla'),
(2473, 'Sincelejo'),
(2474, 'Singapore'),
(2475, 'Singida'),
(2476, 'Sinop'),
(2477, 'Sinpo'),
(2478, 'Sinuiju'),
(2479, 'Sion'),
(2480, 'Sioux Falls'),
(2481, 'Siping'),
(2482, 'Siracusa'),
(2483, 'Sirajganj'),
(2484, 'Sirjan'),
(2485, 'Sirnak'),
(2486, 'Sivas'),
(2487, 'Skien'),
(2488, 'Skierniewice'),
(2489, 'Skikda'),
(2490, 'Skopje'),
(2491, 'Slatina'),
(2492, 'Slobozia'),
(2493, 'Slough'),
(2494, 'Slupsk'),
(2495, 'Smolensk'),
(2496, 'Soacha'),
(2497, 'Sobral'),
(2498, 'Sochi'),
(2499, 'Sofia'),
(2500, 'Sohag'),
(2501, 'Sokoto'),
(2502, 'Soledad'),
(2503, 'Soledad de Graciano Sanchez'),
(2504, 'Solihull'),
(2505, 'Solikamsk'),
(2506, 'Solingen'),
(2507, 'Solothurn'),
(2508, 'Solwezi'),
(2509, 'Songea'),
(2510, 'Songjin'),
(2511, 'Songkhla'),
(2512, 'Songnam'),
(2513, 'Sorocaba'),
(2514, 'Sosnowiec'),
(2515, 'South Bend'),
(2516, 'Southampton'),
(2517, 'Southend on Sea'),
(2518, 'Soweto'),
(2519, 'Soyapango'),
(2520, 'Spokane'),
(2521, 'Springfield'),
(2522, 'Srinagar'),
(2523, 'St. Louis'),
(2524, 'St. Paul'),
(2525, 'St. Petersburg'),
(2526, 'St. Polten'),
(2527, 'Stafford'),
(2528, 'Stamford'),
(2529, 'Stanley'),
(2530, 'Stans'),
(2531, 'Stary Oskol'),
(2532, 'Stavanger'),
(2533, 'Stavropol'),
(2534, 'Steinkjer'),
(2535, 'Sterling Heights'),
(2536, 'Sterlitamak'),
(2537, 'Stirling'),
(2538, 'Stockholm'),
(2539, 'Stockport'),
(2540, 'Stockton'),
(2541, 'Stockton on Tees'),
(2542, 'Stoke on Trent'),
(2543, 'Stornoway'),
(2544, 'Strasbourg'),
(2545, 'Stratford on Avon'),
(2546, 'Stroud'),
(2547, 'Stuttgart'),
(2548, 'Suceava'),
(2549, 'Sucre'),
(2550, 'Suihua'),
(2551, 'Sukabumi'),
(2552, 'Sukkur'),
(2553, 'Sullana'),
(2554, 'Sumare'),
(2555, 'Sumbawanga'),
(2556, 'Sumbe'),
(2557, 'Sumy'),
(2558, 'Sunchon'),
(2559, 'Sunderland'),
(2560, 'Sunnyvale'),
(2561, 'Sunshine Coast'),
(2562, 'Suqian'),
(2563, 'Surabaya'),
(2564, 'Surakarta'),
(2565, 'Surat'),
(2566, 'Surgut'),
(2567, 'Surrey'),
(2568, 'Sutton in Ashfield'),
(2569, 'Suva'),
(2570, 'Suwalki'),
(2571, 'Suwon'),
(2572, 'Suzano'),
(2573, 'Suzhou'),
(2574, 'Svolvaer'),
(2575, 'Swale'),
(2576, 'Swansea'),
(2577, 'Sydney'),
(2578, 'Syktyvkar'),
(2579, 'Sylhet'),
(2580, 'Syracuse'),
(2581, 'Syzran'),
(2582, 'Szczecin'),
(2583, 'Szeged'),
(2584, 'Szekesfehervar'),
(2585, 'Szekszard'),
(2586, 'Szolnok'),
(2587, 'Szombathely'),
(2588, 'Taboao da Serra'),
(2589, 'Tabora'),
(2590, 'Tabriz'),
(2591, 'Tacna'),
(2592, 'Tacoma'),
(2593, 'Taegu'),
(2594, 'Taejon'),
(2595, 'Taganrog'),
(2596, 'Taian'),
(2597, 'Taichung'),
(2598, 'Tainan'),
(2599, 'Taipei'),
(2600, 'Taiping'),
(2601, 'Taitung'),
(2602, 'Taiyuan'),
(2603, 'Taizhou'),
(2604, 'Takamatsu'),
(2605, 'Takoradi'),
(2606, 'Talara'),
(2607, 'Taldyqorghan'),
(2608, 'Tallahassee'),
(2609, 'Tallinn'),
(2610, 'Tamale'),
(2611, 'Tamatave'),
(2612, 'Tambacounda'),
(2613, 'Tambov'),
(2614, 'Tameside'),
(2615, 'Tampa'),
(2616, 'Tampere'),
(2617, 'Tampico'),
(2618, 'Tanchon'),
(2619, 'Tanga'),
(2620, 'Tangail'),
(2621, 'Tanger'),
(2622, 'Tangshan'),
(2623, 'Tanjung Balai'),
(2624, 'Tanta'),
(2625, 'Taoyuan'),
(2626, 'Tapachula'),
(2627, 'Taranto'),
(2628, 'Tarawa'),
(2629, 'Tarnobrzeg'),
(2630, 'Tarnow'),
(2631, 'Tarragona'),
(2632, 'Tarsus'),
(2633, 'Tashauz'),
(2634, 'Tashkent'),
(2635, 'Tatabanya'),
(2636, 'Taubate'),
(2637, 'Taunggyi'),
(2638, 'Taunton'),
(2639, 'Tavoy'),
(2640, 'Tawai'),
(2641, 'Tbilisi'),
(2642, 'Tebessa'),
(2643, 'Tebing Tinggi'),
(2644, 'Tegal'),
(2645, 'Tegucigalpa'),
(2646, 'Tehran'),
(2647, 'Tehuacan'),
(2648, 'Tekirdag'),
(2649, 'Tel Aviv'),
(2650, 'Tela'),
(2651, 'Tema'),
(2652, 'Tembisa'),
(2653, 'Temirtau'),
(2654, 'Tempe'),
(2655, 'Tengxian'),
(2656, 'Teofilo Otoni'),
(2657, 'Tepic'),
(2658, 'Teresina'),
(2659, 'Teresopolis'),
(2660, 'Termiz'),
(2661, 'Terni'),
(2662, 'Ternopil'),
(2663, 'Terrassa'),
(2664, 'Tete'),
(2665, 'Tetouan'),
(2666, 'Thai Nguyen'),
(2667, 'Thane'),
(2668, 'The Valley'),
(2669, 'Thessaloniki'),
(2670, 'Thies'),
(2671, 'Thika'),
(2672, 'Thimphu'),
(2673, 'Thousand Oaks'),
(2674, 'Thunder Bay'),
(2675, 'Tianjin'),
(2676, 'Tianmen'),
(2677, 'Tianshui'),
(2678, 'Tieling'),
(2679, 'Tijuana'),
(2680, 'Tilburg'),
(2681, 'Timisoara'),
(2682, 'Timon'),
(2683, 'Tirane'),
(2684, 'Tirgoviste'),
(2685, 'Tirgu Jiu'),
(2686, 'Tirgu Mures'),
(2687, 'Tiruchchirappalli'),
(2688, 'Tlaquepaque'),
(2689, 'Tlaxcala'),
(2690, 'Tlemcen'),
(2691, 'Toensberg'),
(2692, 'Tokat'),
(2693, 'Tokchon'),
(2694, 'Tokushima'),
(2695, 'Tokyo'),
(2696, 'Toledo'),
(2697, 'Toliara'),
(2698, 'Toluca'),
(2699, 'Toluca de Lerdo'),
(2700, 'Tolyatti'),
(2701, 'Tomsk'),
(2702, 'Tonala'),
(2703, 'Tonbridge'),
(2704, 'Tongchuan'),
(2705, 'Tonghua'),
(2706, 'Tongi'),
(2707, 'Tongliao'),
(2708, 'Tongling'),
(2709, 'Topeka'),
(2710, 'Toronto'),
(2711, 'Torrance'),
(2712, 'Torre del Greco'),
(2713, 'Torreon'),
(2714, 'Torshavn'),
(2715, 'Torun'),
(2716, 'Tottori'),
(2717, 'Toulon'),
(2718, 'Toulouse'),
(2719, 'Tours'),
(2720, 'Townsville'),
(2721, 'Toyama'),
(2722, 'Trabzon'),
(2723, 'Trafford'),
(2724, 'Trento'),
(2725, 'Trenton'),
(2726, 'Trieste'),
(2727, 'Tripoli'),
(2728, 'Trivandrum'),
(2729, 'Tromsoe'),
(2730, 'Trondheim'),
(2731, 'Trowbridge'),
(2732, 'Trujillo'),
(2733, 'Truro'),
(2734, 'Tshikapa'),
(2735, 'Tsu'),
(2736, 'Tucson'),
(2737, 'Tucupita'),
(2738, 'Tula'),
(2739, 'Tulcea'),
(2740, 'Tulsa'),
(2741, 'Tulua'),
(2742, 'Tumaco'),
(2743, 'Tumbes'),
(2744, 'Tunbridge Wells'),
(2745, 'Tunceli'),
(2746, 'Tunis'),
(2747, 'Tunja'),
(2748, 'Turbo'),
(2749, 'Turin'),
(2750, 'Turku'),
(2751, 'Turmero'),
(2752, 'Tuxtla Gutierrez'),
(2753, 'Tver'),
(2754, 'Tychy'),
(2755, 'Tyumen'),
(2756, 'Uberaba'),
(2757, 'Uberlandia'),
(2758, 'Ubon Ratchathani'),
(2759, 'Ufa'),
(2760, 'Uige'),
(2761, 'Ujjain'),
(2762, 'Ujung Pandang'),
(2763, 'Ukhta'),
(2764, 'Ulaanbaatar'),
(2765, 'Ulan Ude'),
(2766, 'Ulanhot'),
(2767, 'Ulhasnagar'),
(2768, 'Ulm'),
(2769, 'Ulsan'),
(2770, 'Umea'),
(2771, 'Uppsala'),
(2772, 'Urawa'),
(2773, 'Urfa'),
(2774, 'Urganch'),
(2775, 'Uruapan'),
(2776, 'Uruguaiana'),
(2777, 'Urumqi'),
(2778, 'Usak'),
(2779, 'Ushuaia'),
(2780, 'Usolye Sibirskoye'),
(2781, 'Ussuriysk'),
(2782, 'Ust Ilimsk'),
(2783, 'Usti nad Labem'),
(2784, 'Utrecht'),
(2785, 'Utsonomiya'),
(2786, 'Uvira'),
(2787, 'Uzhhorod'),
(2788, 'Vaasa'),
(2789, 'Vadodara'),
(2790, 'Vadsoe'),
(2791, 'Vaduz'),
(2792, 'Valencia'),
(2793, 'Valladolid'),
(2794, 'Valledupar'),
(2795, 'Vallejo'),
(2796, 'Valletta'),
(2797, 'Valparaiso'),
(2798, 'Van'),
(2799, 'Vancouver'),
(2800, 'Vanersborg'),
(2801, 'Varanasi'),
(2802, 'Varginha'),
(2803, 'Varzea Grande'),
(2804, 'Vaslui');
INSERT INTO `city` (`ID`, `Name`) VALUES
(2805, 'Vasteras'),
(2806, 'Vatican City'),
(2807, 'Vaughan'),
(2808, 'Vaxjo'),
(2809, 'Velikiye Luki'),
(2810, 'Velsen'),
(2811, 'Venice'),
(2812, 'Veracruz Llave'),
(2813, 'Verona'),
(2814, 'Veszprem'),
(2815, 'Viamao'),
(2816, 'Viana do Castelo'),
(2817, 'Vicente Lopez'),
(2818, 'Vicenza'),
(2819, 'Victoria'),
(2820, 'Victoria de Durango'),
(2821, 'Victoria de las Tunas'),
(2822, 'Viedma'),
(2823, 'Vienna'),
(2824, 'Vientiane'),
(2825, 'Viet Tri'),
(2826, 'Vigo'),
(2827, 'Vijayawada'),
(2828, 'Vila Nova de Gaia'),
(2829, 'Vila Real'),
(2830, 'Vila Velha'),
(2831, 'Villa Nueva'),
(2832, 'Villahermosa'),
(2833, 'Villavicencio'),
(2834, 'Villeurbanne'),
(2835, 'Vilnius'),
(2836, 'Vinnytsya'),
(2837, 'Virginia Beach'),
(2838, 'Visby'),
(2839, 'Viseu'),
(2840, 'Vishakhapatnam'),
(2841, 'Vitoria'),
(2842, 'Vitoria da Conquista'),
(2843, 'Vitoria de Santo Antao'),
(2844, 'Vitoria Gasteiz'),
(2845, 'Vladikavkaz'),
(2846, 'Vladimir'),
(2847, 'Vladivostok'),
(2848, 'Vlore'),
(2849, 'Volgodonsk'),
(2850, 'Volgograd'),
(2851, 'Vologda'),
(2852, 'Volos'),
(2853, 'Volta Redonda'),
(2854, 'Volzhsky'),
(2855, 'Vorkuta'),
(2856, 'Voronezh'),
(2857, 'Votkinsk'),
(2858, 'Vung Tau'),
(2859, 'Waco'),
(2860, 'Wad Madani'),
(2861, 'Wafangdian'),
(2862, 'Wah Cantonment'),
(2863, 'Wakayama'),
(2864, 'Wakefield'),
(2865, 'Wakrah'),
(2866, 'Walbrzych'),
(2867, 'Walsall'),
(2868, 'Wanxian'),
(2869, 'Warangal'),
(2870, 'Warren'),
(2871, 'Warrington'),
(2872, 'Warsaw'),
(2873, 'Warwick'),
(2874, 'Washington'),
(2875, 'Waterbury'),
(2876, 'Waw'),
(2877, 'Weifang'),
(2878, 'Weihai'),
(2879, 'Weinan'),
(2880, 'Wellington'),
(2881, 'Wendeng'),
(2882, 'Wenzhou'),
(2883, 'West Bromwich'),
(2884, 'West Covina'),
(2885, 'West Island'),
(2886, 'Wete'),
(2887, 'Whitehorse'),
(2888, 'Wichita'),
(2889, 'Wichita Falls'),
(2890, 'Wiesbaden'),
(2891, 'Wigan'),
(2892, 'Willemstad'),
(2893, 'Winchester'),
(2894, 'Windhoek'),
(2895, 'Windsor'),
(2896, 'Winnipeg'),
(2897, 'Winston Salem'),
(2898, 'Winterthur'),
(2899, 'Wiral'),
(2900, 'Witten'),
(2901, 'Wloclawek'),
(2902, 'Wodzilaw Slaski'),
(2903, 'Wokingham'),
(2904, 'Wolfsburg'),
(2905, 'Wollongong'),
(2906, 'Wolverhampton'),
(2907, 'Wonsan'),
(2908, 'Worcester'),
(2909, 'Wrexham'),
(2910, 'Wroclaw'),
(2911, 'Wuhai'),
(2912, 'Wuhan'),
(2913, 'Wuhu'),
(2914, 'Wuppertal'),
(2915, 'Wurzburg'),
(2916, 'Wuwei'),
(2917, 'Wuxi'),
(2918, 'Wuzhou'),
(2919, 'Wycombe'),
(2920, 'Xai Xai'),
(2921, 'Xalapa Enriquez'),
(2922, 'Xiamen'),
(2923, 'Xian'),
(2924, 'Xiangfan'),
(2925, 'Xiangtan'),
(2926, 'Xianning'),
(2927, 'Xianyang'),
(2928, 'Xiaogan'),
(2929, 'Xiaoshan'),
(2930, 'Xichang'),
(2931, 'Xingcheng'),
(2932, 'Xinghua'),
(2933, 'Xingtai'),
(2934, 'Xining'),
(2935, 'Xintai'),
(2936, 'Xinxiang'),
(2937, 'Xinyang'),
(2938, 'Xinyu'),
(2939, 'Xuancheng'),
(2940, 'Xuchang'),
(2941, 'Xuzhou'),
(2942, 'Yakeshi'),
(2943, 'Yakutsk'),
(2944, 'Yamagata'),
(2945, 'Yamaguchi'),
(2946, 'Yamoussoukro'),
(2947, 'Yanan'),
(2948, 'Yancheng'),
(2949, 'Yangjiang'),
(2950, 'Yangquan'),
(2951, 'Yangzhou'),
(2952, 'Yanji'),
(2953, 'Yantai'),
(2954, 'Yaounde'),
(2955, 'Yaren'),
(2956, 'Yaroslavl'),
(2957, 'Yasuj'),
(2958, 'Yazd'),
(2959, 'Yekaterinburg'),
(2960, 'Yelets'),
(2961, 'Yellowknife'),
(2962, 'Yerevan'),
(2963, 'Yibin'),
(2964, 'Yichang'),
(2965, 'Yichun'),
(2966, 'Yinchuan'),
(2967, 'Yingkou'),
(2968, 'Yining'),
(2969, 'Yixing'),
(2970, 'Yiyang'),
(2971, 'Yizheng'),
(2972, 'Yogyakarta'),
(2973, 'Yokohama'),
(2974, 'Yongan'),
(2975, 'Yonkers'),
(2976, 'Yopal'),
(2977, 'York'),
(2978, 'Yoro'),
(2979, 'Yoshkar Ola'),
(2980, 'Yosu'),
(2981, 'Yozgat'),
(2982, 'Ystrad Fawr'),
(2983, 'Yuanjiang'),
(2984, 'Yuci'),
(2985, 'Yueyang'),
(2986, 'Yumen'),
(2987, 'Yungho'),
(2988, 'Yuscaran'),
(2989, 'Yushu'),
(2990, 'Yuyao'),
(2991, 'Yuzhno Sakhalinsk'),
(2992, 'Zaanstreek'),
(2993, 'Zabrze'),
(2994, 'Zacatecas'),
(2995, 'Zagazig'),
(2996, 'Zagorsk'),
(2997, 'Zagreb'),
(2998, 'Zahedan'),
(2999, 'Zalaegerszeg'),
(3000, 'Zalau'),
(3001, 'Zamboanga'),
(3002, 'Zamora'),
(3003, 'Zamosc'),
(3004, 'Zanjan'),
(3005, 'Zanzibar'),
(3006, 'Zaoyang'),
(3007, 'Zaozhuang'),
(3008, 'Zapopan'),
(3009, 'Zaporizhzhya'),
(3010, 'Zaragoza'),
(3011, 'Zaria'),
(3012, 'Zelenodolysk'),
(3013, 'Zelenograd'),
(3014, 'Zhambyl'),
(3015, 'Zhangjiakou'),
(3016, 'Zhangzhou'),
(3017, 'Zhanjiang'),
(3018, 'Zhaodong'),
(3019, 'Zhaoqing'),
(3020, 'Zhengzhou'),
(3021, 'Zhenjiang'),
(3022, 'Zhezkazghan'),
(3023, 'Zhezqazghan'),
(3024, 'Zhongshan'),
(3025, 'Zhoukou'),
(3026, 'Zhoushan'),
(3027, 'Zhucheng'),
(3028, 'Zhuhai'),
(3029, 'Zhumadian'),
(3030, 'Zhuzhou'),
(3031, 'Zhytomyr'),
(3032, 'Zibo'),
(3033, 'Zielona Gora'),
(3034, 'Zigong'),
(3035, 'Ziguinchor'),
(3036, 'Zixing'),
(3037, 'Zlatoust'),
(3038, 'Zlin'),
(3039, 'Zonguldak'),
(3040, 'Zug'),
(3041, 'Zunyi'),
(3042, 'Zurich'),
(3043, 'Zwickau'),
(3044, 'Zwolle');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `continent`
--

CREATE TABLE `continent` (
  `ID` int(11) NOT NULL,
  `Name` varchar(16) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `continent`
--

INSERT INTO `continent` (`ID`, `Name`) VALUES
(1, 'Africa'),
(2, 'America'),
(3, 'Asia'),
(4, 'Australia/Oceani'),
(5, 'Europe');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `country`
--

CREATE TABLE `country` (
  `ID` int(11) NOT NULL,
  `Name` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `country`
--

INSERT INTO `country` (`ID`, `Name`) VALUES
(1, 'Afghanistan'),
(2, 'Albania'),
(3, 'Algeria'),
(4, 'American Samoa'),
(5, 'Andorra'),
(6, 'Angola'),
(7, 'Anguilla'),
(8, 'Antigua and Barbuda'),
(9, 'Argentina'),
(10, 'Armenia'),
(11, 'Aruba'),
(12, 'Australia'),
(13, 'Austria'),
(14, 'Azerbaijan'),
(15, 'Bahamas'),
(16, 'Bahrain'),
(17, 'Bangladesh'),
(18, 'Barbados'),
(19, 'Belarus'),
(20, 'Belgium'),
(21, 'Belize'),
(22, 'Benin'),
(23, 'Bermuda'),
(24, 'Bhutan'),
(25, 'Bolivia'),
(26, 'Bosnia and Herzegovina'),
(27, 'Botswana'),
(28, 'Brazil'),
(29, 'British Virgin Islands'),
(30, 'Brunei'),
(31, 'Bulgaria'),
(32, 'Burkina Faso'),
(33, 'Burundi'),
(34, 'Cambodia'),
(35, 'Cameroon'),
(36, 'Canada'),
(37, 'Cape Verde'),
(38, 'Cayman Islands'),
(39, 'Central African Republic'),
(40, 'Chad'),
(41, 'Chile'),
(42, 'China'),
(43, 'Christmas Island'),
(44, 'Cocos Islands'),
(45, 'Colombia'),
(46, 'Comoros'),
(47, 'Congo'),
(48, 'Cook Islands'),
(49, 'Costa Rica'),
(50, 'Cote dIvoire'),
(51, 'Croatia'),
(52, 'Cuba'),
(53, 'Cyprus'),
(54, 'Czech Republic'),
(55, 'Denmark'),
(56, 'Djibouti'),
(57, 'Dominica'),
(58, 'Dominican Republic'),
(59, 'Ecuador'),
(60, 'Egypt'),
(61, 'El Salvador'),
(62, 'Equatorial Guinea'),
(63, 'Eritrea'),
(64, 'Estonia'),
(65, 'Ethiopia'),
(66, 'Falkland Islands'),
(67, 'Faroe Islands'),
(68, 'Fiji'),
(69, 'Finland'),
(70, 'France'),
(71, 'French Guiana'),
(72, 'French Polynesia'),
(73, 'Gabon'),
(74, 'Gambia'),
(75, 'Gaza Strip'),
(76, 'Georgia'),
(77, 'Germany'),
(78, 'Ghana'),
(79, 'Gibraltar'),
(80, 'Greece'),
(81, 'Greenland'),
(82, 'Grenada'),
(83, 'Guadeloupe'),
(84, 'Guam'),
(85, 'Guatemala'),
(86, 'Guernsey'),
(87, 'Guinea'),
(88, 'Guinea-Bissau'),
(89, 'Guyana'),
(90, 'Haiti'),
(91, 'Holy See'),
(92, 'Honduras'),
(93, 'Hong Kong'),
(94, 'Hungary'),
(95, 'Iceland'),
(96, 'India'),
(97, 'Indonesia'),
(98, 'Iran'),
(99, 'Iraq'),
(100, 'Ireland'),
(101, 'Israel'),
(102, 'Italy'),
(103, 'Jamaica'),
(104, 'Japan'),
(105, 'Jersey'),
(106, 'Jordan'),
(107, 'Kazakstan'),
(108, 'Kenya'),
(109, 'Kiribati'),
(110, 'Kosovo'),
(111, 'Kuwait'),
(112, 'Kyrgyzstan'),
(113, 'Laos'),
(114, 'Latvia'),
(115, 'Lebanon'),
(116, 'Lesotho'),
(117, 'Liberia'),
(118, 'Libya'),
(119, 'Liechtenstein'),
(120, 'Lithuania'),
(121, 'Luxembourg'),
(122, 'Macau'),
(123, 'Macedonia'),
(124, 'Madagascar'),
(125, 'Malawi'),
(126, 'Malaysia'),
(127, 'Maldives'),
(128, 'Mali'),
(129, 'Malta'),
(130, 'Man'),
(131, 'Marshall Islands'),
(132, 'Martinique'),
(133, 'Mauritania'),
(134, 'Mauritius'),
(135, 'Mayotte'),
(136, 'Mexico'),
(137, 'Micronesia'),
(138, 'Moldova'),
(139, 'Monaco'),
(140, 'Mongolia'),
(141, 'Montenegro'),
(142, 'Montserrat'),
(143, 'Morocco'),
(144, 'Mozambique'),
(145, 'Myanmar'),
(146, 'Namibia'),
(147, 'Nauru'),
(148, 'Nepal'),
(149, 'Netherlands'),
(150, 'Netherlands Antilles'),
(151, 'New Caledonia'),
(152, 'New Zealand'),
(153, 'Nicaragua'),
(154, 'Niger'),
(155, 'Nigeria'),
(156, 'Niue'),
(157, 'Norfolk Island'),
(158, 'North Korea'),
(159, 'Northern Mariana Islands'),
(160, 'Norway'),
(161, 'Oman'),
(162, 'Pakistan'),
(163, 'Palau'),
(164, 'Panama'),
(165, 'Papua New Guinea'),
(166, 'Paraguay'),
(167, 'Peru'),
(168, 'Philippines'),
(169, 'Pitcairn Islands'),
(170, 'Poland'),
(171, 'Portugal'),
(172, 'Puerto Rico'),
(173, 'Qatar'),
(174, 'Reunion'),
(175, 'Romania'),
(176, 'Russia'),
(177, 'Rwanda'),
(178, 'Saint Helena'),
(179, 'Saint Kitts and Nevis'),
(180, 'Saint Lucia'),
(181, 'Saint Martin'),
(182, 'Saint Pierre and Miquelon'),
(183, 'Saint Vincent and the Grenadines'),
(184, 'Samoa'),
(185, 'San Marino'),
(186, 'Sao Tome and Principe'),
(187, 'Saudi Arabia'),
(188, 'Senegal'),
(189, 'Serbia'),
(190, 'Seychelles'),
(191, 'Sierra Leone'),
(192, 'Singapore'),
(193, 'Slovakia'),
(194, 'Slovenia'),
(195, 'Solomon Islands'),
(196, 'Somalia'),
(197, 'South Africa'),
(198, 'South Korea'),
(199, 'Spain'),
(200, 'Sri Lanka'),
(201, 'Sudan'),
(202, 'Suriname'),
(203, 'Svalbard'),
(204, 'Swaziland'),
(205, 'Sweden'),
(206, 'Switzerland'),
(207, 'Syria'),
(208, 'Taiwan'),
(209, 'Tajikistan'),
(210, 'Tanzania'),
(211, 'Thailand'),
(212, 'Timor-Leste'),
(213, 'Togo'),
(214, 'Tonga'),
(215, 'Trinidad and Tobago'),
(216, 'Tunisia'),
(217, 'Turkey'),
(218, 'Turkmenistan'),
(219, 'Turks and Caicos Islands'),
(220, 'Tuvalu'),
(221, 'Uganda'),
(222, 'Ukraine'),
(223, 'United Arab Emirates'),
(224, 'United Kingdom'),
(225, 'United States'),
(226, 'Uruguay'),
(227, 'Uzbekistan'),
(228, 'Vanuatu'),
(229, 'Venezuela'),
(230, 'Vietnam'),
(231, 'Virgin Islands'),
(232, 'Wallis and Futuna'),
(233, 'West Bank'),
(234, 'Western Sahara'),
(235, 'Yemen'),
(236, 'Zaire'),
(237, 'Zambia'),
(238, 'Zimbabwe');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `currency`
--

CREATE TABLE `currency` (
  `ID` int(11) NOT NULL,
  `Name` varchar(64) NOT NULL,
  `ExchangeRate` decimal(20,9) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `currency`
--

INSERT INTO `currency` (`ID`, `Name`, `ExchangeRate`) VALUES
(1, 'Dollar', '0.832984010'),
(2, 'Pound', '1.157481100'),
(3, 'Yen', '0.007709392'),
(4, 'Ruble', '0.010859994'),
(5, 'Euro', '1.000000000'),
(6, 'Canadian Dollar', '0.664353570'),
(7, 'Mexican Peso', '0.041789164'),
(8, 'Brazil Real', '0.151363080'),
(9, 'Czech Crown', '0.038683146');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `furnishing`
--

CREATE TABLE `furnishing` (
  `ID` int(11) NOT NULL,
  `Description` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `furnishing`
--

INSERT INTO `furnishing` (`ID`, `Description`) VALUES
(1, 'Microwave'),
(2, 'WLAN'),
(3, 'Shower'),
(4, 'Bathtub'),
(5, 'Washing Machine'),
(6, 'TV'),
(7, 'Radiator'),
(8, 'Air Conditioning'),
(9, 'Smoke Detector'),
(10, 'Fire Extinguisher'),
(11, 'Coffee Machine'),
(12, 'Refrigerator'),
(13, 'Dishwasher'),
(14, 'Oven'),
(15, 'Stove'),
(16, 'Cooking Equipment '),
(17, 'Hygiene Products'),
(18, 'Iron'),
(19, 'Hairdryer'),
(20, 'First Aid Kit');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `location`
--

CREATE TABLE `location` (
  `ID` int(11) NOT NULL,
  `Longitude` decimal(17,14) NOT NULL,
  `Latitude` decimal(17,14) NOT NULL,
  `Street` varchar(128) NOT NULL,
  `CityID` int(11) NOT NULL,
  `StateID` int(11) NOT NULL,
  `CountryID` int(11) NOT NULL,
  `ContinentID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `location`
--

INSERT INTO `location` (`ID`, `Longitude`, `Latitude`, `Street`, `CityID`, `StateID`, `CountryID`, `ContinentID`) VALUES
(1, '48.22190583895002', '16.39969909836016', 'Ybbsstrasse 25', 2823, 1351, 13, 5),
(2, '48.21755317532077', '16.38356457776384', 'Rotensterngasse 19', 2823, 1351, 13, 5),
(3, '40.64631339441244', '-73.95102420106161', '118 E 28th St', 1831, 881, 225, 2),
(4, '40.62574392230435', '-73.94560615644012', '1047 E 31st St', 1831, 881, 225, 2),
(5, '51.52190627572071', '-0.10732681531073', '12 Onslow St', 1494, 468, 224, 5),
(6, '51.52623645829883', '-0.12389097051002', '15 Judd St', 1494, 468, 224, 5),
(7, '19.37000687406998', '-99.16670241933878', 'Nicolas San Juan 1628', 1666, 1431, 136, 2),
(8, '19.42097897210246', '-99.16848437625336', 'Valladolid 34', 1666, 1431, 136, 2),
(9, '35.68607912619572', '139.80630699875317', '4-chome-9 Morishita', 2695, 1432, 104, 3),
(10, '35.73282342536184', '139.79836521624813', '7-chome-1 Minamisenju', 2695, 1432, 104, 3),
(11, '41.90013848106450', '12.47237649924136', 'Via di Tor Sanguigna, 13', 2234, 698, 102, 5),
(12, '41.89548592911697', '12.46570568107110', 'Lungotevere Farnesina, 34', 2234, 698, 102, 5),
(13, '-22.94536328598381', '-43.18237204651486', 'Praia de Botafogo, 324', 2218, 1068, 28, 2),
(14, '-22.97314440628752', '-43.41414073541491', 'Av. Canal do Rio Cacambe, 13', 2218, 1068, 28, 2),
(15, '50.08830909738214', '14.42713708073482', 'Kralodvorska 13', 2108, 1433, 54, 5),
(16, '50.07949044665512', '14.42996533890644', 'Vaclavske nam. 67', 2108, 1433, 54, 5),
(17, '55.64936172653379', '37.51488991725466', 'ul. Miklukho-Maklaya, 23', 1729, 1434, 176, 3),
(18, '55.77132584460873', '37.58999230921754', '2-Ya Brestskaya Ulitsa, 23', 1729, 1434, 176, 3),
(19, '43.64602744035566', '-79.38306879535791', '56 York St', 2710, 952, 36, 2),
(20, '43.68098901116819', '-79.42959478114817', '788 St Clair Ave W', 2710, 952, 36, 2),
(21, '48.22221859746513', '16.39909413775379', 'Harkortstrasse', 2823, 1351, 13, 5),
(22, '48.22368749354632', '16.40118089628831', 'Vorgartenstrasse', 2823, 1351, 13, 5),
(23, '48.21901970980362', '16.38061799543274', 'Taborstrasse', 2823, 1351, 13, 5),
(24, '48.21618671266512', '16.38657373480088', 'Nestroyplatz', 2823, 1351, 13, 5),
(25, '40.64708804931311', '-73.95202774171081', 'Rogers Ave/Tilden Av', 1831, 881, 225, 2),
(26, '40.64508805162596', '-73.94899102237397', 'Beverly Road Station', 1831, 881, 225, 2),
(27, '40.62467036394659', '-73.94327527278055', 'Ave K /New York Av', 1831, 881, 225, 2),
(28, '40.62947131381076', '-73.94398637124125', 'Flatbush Av/Av I', 1831, 881, 225, 2),
(29, '51.52056851205845', '-0.10603992679564', 'Farringdon Station (Stop A)', 1494, 468, 224, 5),
(30, '51.52225843174391', '-0.10556956798408', 'Clerkenwell Green (Stop K)', 1494, 468, 224, 5),
(31, '51.52503002119396', '-0.12808269178101', 'Tavistock Square (Stop N)', 1494, 468, 224, 5),
(32, '51.52900248225155', '-0.12688157894151', 'British Library (Stop C)', 1494, 468, 224, 5),
(33, '19.37113655912380', '-99.16437073468810', 'Terminal Metro Zapata', 1666, 1431, 136, 2),
(34, '19.37127254137619', '-99.16815636447790', 'Eje 7 Sur Felix Cuevas - Gabriel Mancera', 1666, 1431, 136, 2),
(35, '19.42225123525758', '-99.17032365653134', 'Sevilla-av Chapultepec', 1666, 1431, 136, 2),
(36, '19.41936936608681', '-99.16981330422357', 'Eje 3 Poniente Salamanca', 1666, 1431, 136, 2),
(37, '35.68716210785912', '139.80601094776470', 'Kikukawa Sta.', 2695, 1432, 104, 3),
(38, '35.68310675035403', '139.80659658047418', 'Shirakawa', 2695, 1432, 104, 3),
(39, '35.73361207710308', '139.80008379123097', 'Minamisenju Eki Higashiguchi', 2695, 1432, 104, 3),
(40, '35.72944671833231', '139.79937954590895', 'Namidabashi', 2695, 1432, 104, 3),
(41, '41.90103455352219', '12.47221413530060', 'Zanardelli', 2234, 698, 102, 5),
(42, '41.89804922963433', '0.00000000000000', 'Rinascimento', 2234, 698, 102, 5),
(43, '41.89445513489437', '12.46687422515407', 'Lgt Farnesina', 2234, 698, 102, 5),
(44, '41.89637134550479', '12.46145842812875', 'Psg Gianicolo/Poliambulatorio', 2234, 698, 102, 5),
(45, '-22.94726569945416', '-43.18209833132629', 'Praia de Botafogo proximo ao 2957-3201', 2218, 1068, 28, 2),
(46, '-22.94359036408407', '-43.18366474133162', 'Rua Muniz Barreto proximo ao 51-207', 2218, 1068, 28, 2),
(47, '-22.97228970051078', '-43.41391265291447', 'Estrada dos Bandeirantes proximo ao 8315-8321', 2218, 1068, 28, 2),
(48, '-22.97370224309168', '-43.41074228197901', 'Rua Abrahao Jabour proximo ao 740-858', 2218, 1068, 28, 2),
(49, '50.08863730405031', '14.42945178746094', 'Namesti Republiky', 2108, 1433, 54, 5),
(50, '50.08932655335201', '14.42435149750781', 'Masna', 2108, 1433, 54, 5),
(51, '50.08211169200811', '14.42587148812534', 'Vaclavske nam. 67', 2108, 1433, 54, 5),
(52, '50.07985282590142', '14.43139441094493', 'Muzeum', 2108, 1433, 54, 5),
(53, '55.64838466948287', '37.51378291390149', 'Akademika Volgina St', 1729, 1434, 176, 3),
(54, '55.65085460742434', '37.50638001730091', 'Meditsinskiy fakultet', 1729, 1434, 176, 3),
(55, '55.77191023133850', '37.59244457561380', 'Yuliusa Fuchika St', 1729, 1434, 176, 3),
(56, '55.77063856016756', '37.59538052496981', 'Mayakovskaya Station', 1729, 1434, 176, 3),
(57, '43.64524528084401', '-79.38063146954936', 'Union Station', 2710, 952, 36, 2),
(58, '43.64780723926258', '-79.38373210305308', 'York St At King St West', 2710, 952, 36, 2),
(59, '43.68023320610153', '-79.43288365244469', 'Winona', 2710, 952, 36, 2),
(60, '43.68210445405745', '-79.42393927323420', 'St Clair Ave West at Wychwood Ave West Side', 2710, 952, 36, 2),
(61, '48.20565062890334', '16.36478029835976', 'Hofburg', 2823, 1351, 13, 5),
(62, '48.18581953232709', '16.31275326952357', 'Schoenbrunner Schlossstrasse 47', 2823, 1351, 13, 5),
(63, '40.68926437283371', '-74.04448191025169', 'Liberty Island', 1831, 881, 225, 2),
(64, '40.78127035520602', '-73.96653421292417', '79th Street & 85th Street', 1831, 881, 225, 2),
(65, '51.50329727963649', '-0.11954297271940', 'Riverside Building', 1494, 468, 224, 5),
(66, '51.50137065829317', '-0.14193291689773', 'London SW1A 1AA', 1494, 468, 224, 5),
(67, '19.43265452959020', '-99.13319473217284', 'P.za de la Constitucion', 1666, 1431, 136, 2),
(68, '19.43527008916251', '-99.14125197060780', 'Av. Juarez', 1666, 1431, 136, 2),
(69, '35.68527585231959', '139.75272408610033', '1-1 Chiyoda', 2695, 1432, 104, 3),
(70, '35.71476367281087', '139.79665382929930', '2 Chome-3-1 Asakusa', 2695, 1432, 104, 3),
(71, '41.89021017922426', '12.49218798286854', 'Piazza del Colosseo', 2234, 698, 102, 5),
(72, '41.89761455101515', '12.49841912704692', 'P.za di Santa Maria Maggiore', 2234, 698, 102, 5),
(73, '-22.95191259488967', '-43.21049229678676', 'Parque Nacional da Tijuca - Alto da Boa Vista', 2218, 1068, 28, 2),
(74, '-22.94929752838458', '-43.15457573013092', 'Urca', 2218, 1068, 28, 2),
(75, '50.09108969614250', '14.40160576957218', 'Hradcany', 2108, 1433, 54, 5),
(76, '50.08648396337884', '14.41142586957209', 'Karluv most', 2108, 1433, 54, 5),
(77, '55.75200516676532', '37.61747794089056', 'Vozdvizhenka St. 1/13', 1729, 1434, 176, 3),
(78, '55.75250476699738', '37.62306534089070', 'Red Square', 1729, 1434, 176, 3),
(79, '43.66770967912377', '-79.39477710174906', '100 Queens Park', 2710, 952, 36, 2),
(80, '43.65442265414673', '-79.38071013058503', '220 Yonge St', 2710, 952, 36, 2);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `lodging`
--

CREATE TABLE `lodging` (
  `ID` int(11) NOT NULL,
  `Description` varchar(128) NOT NULL,
  `Category` varchar(64) NOT NULL,
  `About` text NOT NULL,
  `Capacity` int(11) NOT NULL,
  `Rating` decimal(2,1) DEFAULT NULL,
  `Price` decimal(7,2) NOT NULL,
  `CurrencyID` int(11) NOT NULL,
  `LocationID` int(11) NOT NULL,
  `UsersID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `lodging`
--

INSERT INTO `lodging` (`ID`, `Description`, `Category`, `About`, `Capacity`, `Rating`, `Price`, `CurrencyID`, `LocationID`, `UsersID`) VALUES
(1, 'Lovely Apartment in Heart of Vienna near Metro!', 'Apartment', 'Very lovely and comfortable apartment near the metro U1 - Vorgartenstrasse. Ideal for couples or family trip with child. Comfortable bed in a room. Also, a sofa with a neat little table for relaxing, the sofa unfolds and accommodates 1 person more. The apartment has everything you need for cooking, as well as beds made of clean sheets, pillowcases, duvet covers, and a towel per person are prepared for your arrival. Free wifi', 3, '4.2', '25.00', 5, 1, 1),
(2, 'Room with terrace, Vienna, next to downtown, metro', 'Room', 'Right on the pulse of the city, convinces with its central and urban location with great infrastructure. Numerous restaurants, supermarkets, bars & clubs are easy to reach. The property is suitable for couples and solo adventurers who want to explore the city. Book today and save money!', 2, '3.4', '14.00', 5, 2, 1),
(3, 'Flatbush Hideaway - Quiet and close to subway!', 'House', 'Newly renovated, LED Lighting, smart plugs and outlets. Private entry and full bath with stall shower. Quiet and clean! The space is in the historic Flatbush section of Brooklyn and short 2 minute walk to the subway! Contact me directly if you\'\'re interested in staying more than 14 days.', 4, '4.8', '48.00', 1, 3, 3),
(4, 'Queen Room', 'Room', 'Must-visit shops, eateries & sights are right on your doorstep. Smart design & refined style flow throughout this contemporary atmosphere. Rendezvous at the hotel restaurant & bar & savor killer city views from the rooftop terrace.', 2, '4.8', '70.00', 1, 4, 3),
(5, 'Studio Flat Farringdon, Clerkenwell, Holborn 501A', 'Apartment', 'There is small desk space with an office chair, and its own personal WiFi router is provided. A double wardrobe containing plenty of hanging and storage space. Fully functional kitchen complete with a hob, microwave, toaster and kettle; alongside all cookware and utensils and its own fridge freezer. Its own private bathroom (pod), small but has everything you need.', 1, '2.7', '86.00', 2, 5, 5),
(6, 'Private studio in Central London', 'Apartment', 'Although our apartments are self-contained our buildings are not. Therefore in line with government guidelines guests must self-certify prior to arrival. This will be required until leisure stays are fully permitted (currently date is 17th May). Perfect for one person, or cosy for two. Styled on our larger studios, the City Studios include all you need with super-fast Wi-Fi, interactive TV with ability to stream content direct from your laptop or mobile device, mini kitchen, spacious bathroom, and independently controlled airconditioning.', 2, '4.0', '55.00', 2, 6, 5),
(7, 'Bonito centrico LOFT C/Jacuzzi en terraza privada', 'Loft', '50m2 room w/Jacuzzi on private terrace, double bedroom, sofa bed, 2 individual air mattresses, minibar, coffee maker, bar/canteen, 65?TV (Netflix, Amazon, Blim, IZZI Premium), HK horn, desk, hair dryer, iron p/clothes, barbecue, outdoor laundry wash, garden dining room, independent access to the apartment, elevator, are 5 min 3 commercial spaces, cinemas, restaurants, cafes, bars, banks, park, ISSSTE Hospital November 20 and others, 7Eleven on corner.', 4, '3.9', '830.00', 7, 7, 7),
(8, 'Nice historic porfirian apt with terrace', 'House', 'High ceilings and wood floors are part of these beautiful rooms, the bathroom and closet are huge and very comfortable. The apartment is a pleasant walk from the Bosque de Chapultepec museums, including Museo de Arte Moderno, Museo Tamayo, and the world-famous Museo de Antropologia e Historia.', 4, '4.7', '920.00', 7, 8, 7),
(9, 'H2O Stay Morishita 4ppl wifi 5min to station', 'Apartment', 'We have re-innovated our rooms for family guest with big and spacious rooms so that whole family members can relax! Each room can accommodate four guests with one double bed and double size sofa bed. We have basic utilities for guests to enjoy cooking and relaxing time in the room. Tokyo trip may be busy . But we will serve our guest cozy and relaxing time to get refreshed for the trip. Welcome to Tokyo!', 4, '3.1', '14000.00', 3, 9, 9),
(10, 'TokyoGuest#403', 'Room', 'Newly renovated in Dec 2018. Opened in March 2019 for a comfortable stay. The house is located in Nipponbashi Business, Nipponbashi, Chuo-ku, good location, very convenient transportation, 18 minutes on foot to Tokyo Station, Imperial Palace and other attractions.', 2, '3.7', '12300.00', 3, 10, 9),
(11, 'Piazza Navona Penthouse, nel cuore di Roma!', 'Apartment', 'The recently renovated apartment is located near one of the most important squares in Rome, Piazza Navona! The house consists of a large living room with a beautiful fireplace, a kitchen complete with all the comforts and cooking utensils, two bathrooms, a bedroom upstairs with another private bathroom for the bedroom. The house has two air conditioners on both floors, and comes with free and fast Wi-Fi. In the neighborhood you can experience the true spirit of Rome!', 3, '3.9', '49.00', 5, 11, 11),
(12, 'Casa Trastevere', 'Apartment', 'Casa Trastevere is located in the Roman Historical Centre opposite the famous Piazza Trilussa, near Piazza Navona, Piazza Campo de Fiori, Castel Sant\'\'Angelo, Pantheon, Fontana di Trevi and Vatican. Composed of a kitchenette, a bedroom with a LED TV and a bathroom. Maximum of 2 people can stay in the apartment.', 2, '4.5', '51.00', 5, 12, 11),
(13, 'Loft com vista maravilhosa do Pao de Acucar', 'Loft', 'Cozy decoration. Apartment is located on top of two pharmacies, very close to Bobs, South Zone Market, home and video . Airy, it\'\'s on the 12th floor windy, facing the beach. Ceiling fan in the living room and room.350m away from Praia Shopping.Facing Botafogo beach, driving in the door.500 m away.5 min walking to the subway station. Refrigerator,microwave, electric cooker,electric stove and blender.', 4, '4.9', '73.00', 8, 13, 13),
(14, 'FLATS MIDAS RIO - H', 'Room', 'New apartment, well lit, unobstructed view, air conditioned with split, refrigerator, microwave, television, LED TV, all furnished and with built-in wardrobes. In the residential complex you can enjoy the fitness area, the steam sauna and a parking lot on the ground floor of the accommodation (subject to availability) with concierge, reception and 24-hour security service as well as a shopping center next to convenience stores and beauty salons, pharmacies, banks, doctors, Restaurants, pet shop, etc.', 2, '4.3', '67.00', 8, 14, 13),
(15, 'Best Location in Prague - Old Town', 'Apartment', 'This is an apartment INSIDE another apartment. It just means you have to walk through a hallway to enter. Minutes from Old Town Square, Namesti Republiky, and Wenceclas Square. The Airport tram stop is 2 minutes away. Walk to Florenc Main Bus station in 8 minutes and Hlavni Nadrazi Main Train station in 12 minutes. Access tourist sites, grocery stores, clubs, restaurants, Beer Garden, Letna Park, etc. Have your own apartment on an awesome street in the most historic neighborhood in Prague.', 4, '4.6', '460.00', 9, 15, 15),
(16, 'Prague Absolute Centre Hideaway', 'Loft', 'Central penthouse in the heart of Prague, five steps from Mustek metro station and legendary Wenceslas Square. Enjoy comfy nest in centre of Old Town with large bedroom and living room with well equipped kitchen and another sleeping place.', 7, '4.2', '900.00', 9, 16, 15),
(17, 'Belyajevo Studio Moscow', 'Room', 'The room has accommodated all the most important things for a comfortable stay. Functional furniture, necessary equipment, hygiene items', 2, '4.1', '2700.00', 4, 17, 17),
(18, 'Quiet cozy studio in the centre of Moscow', 'Apartment', 'Cozy & quiet Provence styled studio in the pure centre of Moscow, 2 minutes from Belorusskaya metro station (2 Brestskaya ul., dom 43). Walking distance of the Tverskaya street, Moscow Academic Theatre of Satire and Bulgakov Museum. Great neighbourhood with a lot of restaurants, cafes & pubs, such as, for example, Corner Burger, Varenichnaya ? 1 (?????????? ?1), etc.', 3, '3.6', '2340.00', 4, 18, 17),
(19, 'Maple Leaf Sq. +Patio - 1BR + Sofabed - Jays, MTCC', 'Apartment', 'Cozy, spacious and inviting, you\'ll feel perfectly at home in my luxury suite . There is one bedroom with a queen sized bed, and the sofa in the living room turns into a bed that comfortably sleeps two people. The building offers paid visitor parking with direct suite access through the elevators.', 4, '4.6', '100.00', 6, 19, 19),
(20, 'Cosy basement apartment with free parking!', 'Apartment', 'Cute studio apartment with onsite free parking! High-end, quiet and safe Toronto neighborhood! Bus stop outside of the house. Bus will take you to Toronto\'\'s main subway line (Yonge Line) in 4 minutes. If you prefer to walk subway and Toronto\'\'s main street is just 9 min walk from the house. 10 min cab drive to downtown. Supermarket 6 min walk. Gym 9 min walk. To CN Tower by public transportation from door to door 30 min.', 2, '1.7', '55.00', 6, 20, 19);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `lodging_furnishing`
--

CREATE TABLE `lodging_furnishing` (
  `LodgingID` int(11) NOT NULL,
  `FurnishingID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `lodging_furnishing`
--

INSERT INTO `lodging_furnishing` (`LodgingID`, `FurnishingID`) VALUES
(1, 3),
(1, 6),
(1, 10),
(1, 11),
(1, 12),
(1, 14),
(1, 16),
(1, 17),
(1, 18),
(1, 19),
(2, 3),
(2, 4),
(2, 5),
(2, 7),
(2, 9),
(2, 10),
(2, 17),
(2, 18),
(2, 19),
(2, 20),
(3, 1),
(3, 2),
(3, 4),
(3, 6),
(3, 11),
(3, 12),
(3, 15),
(3, 16),
(3, 17),
(3, 20),
(4, 4),
(4, 9),
(4, 10),
(4, 11),
(4, 13),
(4, 14),
(4, 15),
(4, 17),
(4, 18),
(4, 20),
(5, 1),
(5, 2),
(5, 5),
(5, 6),
(5, 8),
(5, 11),
(5, 13),
(5, 14),
(5, 17),
(5, 18),
(6, 5),
(6, 6),
(6, 8),
(6, 9),
(6, 14),
(6, 15),
(6, 16),
(6, 18),
(6, 19),
(6, 20),
(7, 1),
(7, 5),
(7, 6),
(7, 7),
(7, 8),
(7, 10),
(7, 13),
(7, 14),
(7, 16),
(7, 20),
(8, 1),
(8, 3),
(8, 8),
(8, 9),
(8, 12),
(8, 13),
(8, 14),
(8, 15),
(8, 17),
(8, 18),
(9, 1),
(9, 2),
(9, 3),
(9, 4),
(9, 7),
(9, 8),
(9, 9),
(9, 10),
(9, 14),
(9, 18),
(10, 1),
(10, 4),
(10, 7),
(10, 9),
(10, 10),
(10, 11),
(10, 14),
(10, 15),
(10, 16),
(10, 19),
(11, 2),
(11, 3),
(11, 5),
(11, 8),
(11, 10),
(11, 11),
(11, 14),
(11, 15),
(11, 19),
(11, 20),
(12, 1),
(12, 3),
(12, 6),
(12, 8),
(12, 9),
(12, 11),
(12, 13),
(12, 14),
(12, 19),
(12, 20),
(13, 1),
(13, 4),
(13, 8),
(13, 10),
(13, 11),
(13, 13),
(13, 14),
(13, 15),
(13, 18),
(13, 20),
(14, 2),
(14, 3),
(14, 5),
(14, 6),
(14, 9),
(14, 11),
(14, 14),
(14, 15),
(14, 16),
(14, 19),
(15, 3),
(15, 4),
(15, 5),
(15, 6),
(15, 8),
(15, 13),
(15, 15),
(15, 17),
(15, 18),
(15, 19),
(16, 1),
(16, 3),
(16, 9),
(16, 10),
(16, 11),
(16, 13),
(16, 14),
(16, 15),
(16, 19),
(16, 20),
(17, 1),
(17, 2),
(17, 5),
(17, 9),
(17, 10),
(17, 11),
(17, 12),
(17, 13),
(17, 16),
(17, 19),
(18, 3),
(18, 4),
(18, 5),
(18, 7),
(18, 8),
(18, 9),
(18, 11),
(18, 17),
(18, 19),
(18, 20),
(19, 1),
(19, 3),
(19, 5),
(19, 6),
(19, 7),
(19, 8),
(19, 9),
(19, 13),
(19, 14),
(19, 15),
(20, 1),
(20, 2),
(20, 4),
(20, 7),
(20, 13),
(20, 14),
(20, 15),
(20, 16),
(20, 18),
(20, 19);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `lodging_policy`
--

CREATE TABLE `lodging_policy` (
  `LodgingID` int(11) NOT NULL,
  `PolicyID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `lodging_policy`
--

INSERT INTO `lodging_policy` (`LodgingID`, `PolicyID`) VALUES
(1, 1),
(1, 4),
(1, 5),
(2, 1),
(2, 3),
(2, 4),
(3, 2),
(3, 3),
(3, 5),
(4, 2),
(4, 4),
(4, 5),
(5, 1),
(5, 3),
(5, 5),
(6, 2),
(6, 3),
(6, 4),
(7, 1),
(7, 4),
(7, 5),
(8, 2),
(8, 4),
(8, 5),
(9, 2),
(9, 3),
(9, 5),
(10, 1),
(10, 3),
(10, 5),
(11, 2),
(11, 3),
(11, 5),
(12, 1),
(12, 3),
(12, 4),
(13, 2),
(13, 4),
(13, 5),
(14, 2),
(14, 4),
(14, 5),
(15, 2),
(15, 3),
(15, 4),
(16, 1),
(16, 3),
(16, 5),
(17, 2),
(17, 3),
(17, 5),
(18, 2),
(18, 3),
(18, 5),
(19, 2),
(19, 3),
(19, 5),
(20, 2),
(20, 4),
(20, 5);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `lodging_room`
--

CREATE TABLE `lodging_room` (
  `LodgingID` int(11) NOT NULL,
  `RoomID` int(11) NOT NULL,
  `Number` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `lodging_room`
--

INSERT INTO `lodging_room` (`LodgingID`, `RoomID`, `Number`) VALUES
(1, 1, 1),
(1, 2, 1),
(1, 5, 1),
(1, 6, 1),
(1, 7, 1),
(2, 1, 1),
(3, 1, 2),
(3, 2, 3),
(3, 3, 1),
(3, 4, 2),
(3, 5, 3),
(3, 6, 1),
(3, 7, 1),
(4, 1, 1),
(5, 1, 1),
(5, 2, 1),
(5, 3, 1),
(5, 5, 1),
(5, 6, 1),
(6, 1, 1),
(6, 2, 1),
(6, 3, 1),
(6, 4, 1),
(6, 5, 1),
(6, 6, 1),
(7, 1, 1),
(7, 2, 1),
(7, 5, 1),
(7, 6, 1),
(8, 1, 1),
(8, 2, 2),
(8, 3, 1),
(8, 4, 3),
(8, 5, 1),
(8, 6, 1),
(8, 7, 1),
(9, 1, 1),
(9, 2, 1),
(9, 3, 1),
(9, 5, 1),
(9, 6, 1),
(10, 1, 1),
(11, 1, 1),
(11, 2, 1),
(11, 6, 1),
(12, 1, 1),
(12, 2, 1),
(12, 4, 1),
(12, 5, 1),
(12, 6, 1),
(12, 7, 1),
(13, 1, 1),
(13, 2, 1),
(13, 3, 1),
(13, 6, 1),
(14, 1, 1),
(15, 1, 1),
(15, 2, 1),
(15, 5, 1),
(15, 6, 1),
(15, 7, 1),
(16, 1, 1),
(16, 2, 1),
(16, 3, 1),
(16, 4, 1),
(16, 6, 1),
(17, 1, 1),
(18, 1, 1),
(18, 2, 1),
(18, 4, 1),
(18, 6, 1),
(18, 7, 1),
(19, 1, 1),
(19, 2, 1),
(19, 3, 1),
(19, 4, 1),
(19, 5, 1),
(19, 6, 1),
(20, 1, 1),
(20, 2, 1),
(20, 5, 1),
(20, 6, 1),
(20, 7, 1);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `lodging_rule`
--

CREATE TABLE `lodging_rule` (
  `LodgingID` int(11) NOT NULL,
  `RuleID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `lodging_rule`
--

INSERT INTO `lodging_rule` (`LodgingID`, `RuleID`) VALUES
(1, 2),
(1, 4),
(1, 5),
(2, 2),
(2, 3),
(2, 4),
(3, 1),
(3, 3),
(3, 5),
(4, 1),
(4, 2),
(4, 5),
(5, 2),
(5, 3),
(5, 4),
(6, 1),
(6, 3),
(6, 4),
(7, 1),
(7, 3),
(7, 4),
(8, 1),
(8, 2),
(8, 4),
(9, 2),
(9, 3),
(9, 5),
(10, 1),
(10, 2),
(10, 4),
(11, 1),
(11, 2),
(11, 4),
(12, 1),
(12, 2),
(12, 4),
(13, 1),
(13, 2),
(13, 5),
(14, 1),
(14, 3),
(14, 4),
(15, 1),
(15, 3),
(15, 5),
(16, 1),
(16, 3),
(16, 4),
(17, 1),
(17, 3),
(17, 5),
(18, 1),
(18, 4),
(18, 5),
(19, 2),
(19, 4),
(19, 5),
(20, 1),
(20, 4),
(20, 5);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `paymentoption`
--

CREATE TABLE `paymentoption` (
  `ID` int(11) NOT NULL,
  `Name` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `paymentoption`
--

INSERT INTO `paymentoption` (`ID`, `Name`) VALUES
(3, 'Credit Card'),
(2, 'Debit Card'),
(4, 'PayPal'),
(1, 'Wire Transfer');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `policy`
--

CREATE TABLE `policy` (
  `ID` int(11) NOT NULL,
  `Description` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `policy`
--

INSERT INTO `policy` (`ID`, `Description`) VALUES
(1, 'Free cancellation up to 24 hours before check-in. After that, if you cancel before check-in, you\'ll get a full refund minus the first night and service charge.'),
(2, 'Free cancellation up to five days before check-in. After that, if you cancel before check-in, you will receive a 50% refund minus the first night and service charge.'),
(3, 'If the accommodation is left dirty, we reserve the right to have the accommodation cleaned by a cleaning company. The costs incurred will be passed on to you.'),
(4, 'If the accommodation is damaged, we reserve the right to pass on the costs for the repairs to you.'),
(5, 'The host can cancel the planned stay without giving a reason. You will then receive a refund equal to 100 percent of the price.');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `publictransport`
--

CREATE TABLE `publictransport` (
  `ID` int(11) NOT NULL,
  `Description` varchar(64) NOT NULL,
  `LocationID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `publictransport`
--

INSERT INTO `publictransport` (`ID`, `Description`, `LocationID`) VALUES
(1, 'Bus Stop', 21),
(2, 'Metro Station', 22),
(3, 'Metro Station', 23),
(4, 'Metro Station', 24),
(5, 'Bus Stop', 25),
(6, 'Tram Station', 26),
(7, 'Bus Stop', 27),
(8, 'Bus Stop', 28),
(9, 'Bus Stop', 29),
(10, 'Bus Stop', 30),
(11, 'Bus Stop', 31),
(12, 'Bus Stop', 32),
(13, 'Bus Stop', 33),
(14, 'Metro Station', 34),
(15, 'Bus Stop', 35),
(16, 'Bus Stop', 36),
(17, 'Bus Stop', 37),
(18, 'Bus Stop', 38),
(19, 'Bus Stop', 39),
(20, 'Bus Stop', 40),
(21, 'Bus Stop', 41),
(22, 'Bus Stop', 42),
(23, 'Bus Stop', 43),
(24, 'Bus Stop', 44),
(25, 'Bus Stop', 45),
(26, 'Bus Stop', 46),
(27, 'Bus Stop', 47),
(28, 'Bus Stop', 48),
(29, 'Bus Stop', 49),
(30, 'Tram Station', 50),
(31, 'Tram Station', 51),
(32, 'Metro Station', 52),
(33, 'Bus Stop', 53),
(34, 'Bus Stop', 54),
(35, 'Bus Stop', 55),
(36, 'Bus Stop', 56),
(37, 'Metro Station', 57),
(38, 'Tram Station', 58),
(39, 'Tram Station', 59),
(40, 'Tram Station', 60);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `review`
--

CREATE TABLE `review` (
  `ID` int(11) NOT NULL,
  `Content` text NOT NULL,
  `Rating` decimal(2,1) NOT NULL,
  `BookingID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `review`
--

INSERT INTO `review` (`ID`, `Content`, `Rating`, `BookingID`) VALUES
(1, 'Was a great stay considering the price. Fast responding host, all necessary features were included in the apparent. At first there was not a blow drier found, however the friendly host had fixed the issue in an hour and provided the blow drier.', '3.3', 1),
(2, 'The host was super friendly, always replying fast and gave me all the information needed. Definitely recommandable!', '5.0', 2),
(3, 'Okay for a few nights. Host is very polite. Only thing I\'m not happy with is that the room was not cleaned upon arrival, but the host sorted it out very quickly.', '2.7', 3),
(4, 'Centrally situated and price-worthy place. Ideal for short term stays but also convenient for longer stays', '4.0', 4),
(5, 'Great apartment, very cozy and pr?vate with all the amenities needed. Excellent host who was always ready yo meet My needs. This has got to be the Best basement apartment i\'ve been. And only one block from the metro station . definately recomend this place', '4.7', 5),
(6, 'Always my go-to place!', '4.9', 6),
(7, 'Very nice staff, such a cute hotel in a very nice location downtown Manhattan and the roof top was EVERYTHINGGGG', '5.0', 7),
(8, 'This second time using this please great location great place very clean thank y?all for great hospitality', '4.6', 8),
(9, 'Good place for a short stay. Great location!', '4.3', 9),
(10, 'First (& hopefully only!) bad experience with AirBnB lodging & host. Steep stairs should come with a warning, the room should come with a measurement per m2 (so tiny). Very pricey for what it is. The best thing I can say is that the location of the AirBnB is great. Worst thing I can say: hands down the worst host I had to deal with. I also felt watched. Felt like I had 0 privacy. I had to leave the night of & preferred to stay at the airport. Wouldn?t recommend it to a single woman travelling alone. Just my opinion.', '1.0', 10),
(11, 'Great place to stop over - no frills but what you need.', '3.8', 11),
(12, 'Good value for money in a great location', '4.1', 12),
(13, 'Good place to stay one night before the flight but expect that it could be chilly at the winter', '3.5', 13),
(14, 'Perfect location. Spacious accommodations. Clean. Clear communication.', '4.3', 14),
(15, 'This apartment is perfect for a stay in Mexico City. The location ca not be beat- short and beautiful walks away from tons of the best bars, restaurants and shops. The apartment itself was excellent too. Comfortable bed, plenty of room, fast wifi if you need to work, and a quiet building overall. Karina was an excellent host and responded to me within minutes. Will definitely be coming back!', '5.0', 15),
(16, 'Quiet and stylish place to get away from the hustle and bustle of Mexico City. Highly recommend staying here if you have the chance!', '4.3', 16),
(17, 'The places was okay. It was not the best, unfortunately. But, since I did npt see other comments with the same experience I had. I wonder if it was just a mistake and the cleaning person mess up. The beds and towels smell bad. Like someone just had checked out the same day and they did not have time to change or air out. The doors of my apartment open by themselves on my 3rd day and that was scary because at that time I was sleeping alone and did not feel safe. There was an earthquake the 2nd day I stay there and the front door did not want to open. Fortunately there was a guy who was staying there and managed to open it before the earthquake happened. The neighborhood is nice and close to a lot of good restaurants and supper', '2.3', 17),
(18, 'Very nice place in a central location!', '3.9', 18),
(19, 'Clean convenient, close to many subway stations including Tokyo station. Everything you need, and quiet as there was only one other guest at the time we were there.', '4.1', 19),
(20, 'Very decent accommodations. It is a multiple story building but there is an elevator. There is also a washing machine and a dryer on the roof. Staff are very friendly. Can speak English, Japanese and Chinese. Location 1 train station away from Akihabara and near multiple train stations. Very convenient. Some food stores and convenience stores around nearby as well.', '3.2', 20),
(21, 'Place is kept quite clean. There was a microwave, an electric teapot, and a refrigerator in the common area. There was ample space in the room that I had and the hosts were very kind.', '4.6', 21),
(22, 'A bit of a walk from the station but very comfy place to stay.', '3.2', 22),
(23, 'Easy self check in and check out. The location is perfect for a young couple. He responded quickly and the place was very pleasant.', '4.7', 23),
(24, 'A cute apartment in a brilliant location in the heart of Rome, perfectly located for all central sights and attractions.', '4.2', 24),
(25, 'Great location in a prime spot of Trastevere. Self check-in was very easy. Highly recommend this apartment if you want to be in the heart of the night life.', '5.0', 25),
(26, 'A perfect AirBnB in the heart of Trastevere.', '4.8', 26),
(27, 'The best view of Rio right at your window. If your are an early bird there is no other place you would rather be for the sunrise. Botafogo is also a nice neighborhood, with several bars and restaurants, you will certainly find a good place to decompress after a tough day.', '4.5', 27),
(28, 'Absolutely amazing view, nice area, host is very helpful, quick responses. Loved our stay!', '4.0', 28),
(29, 'Perfect!!!', '5.0', 29),
(30, 'Great hosts and very nice apartment!', '4.1', 30),
(31, 'The apartment is in a great location and many sights are within walking distance. There are a couple bars, a currency exchange place and a shopping center nearby. Check-in and check-out were also very easy.', '4.8', 31),
(32, 'Wifi was bad and it would be better if toilet is not shared toilet. Location is perfect, hosts are so nice and it was easy to communicate :)', '3.6', 32),
(33, 'Nice place to stay. Location is amazing and definitely worth to accommodate.', '4.3', 33),
(34, 'It is a well place appartement ! Great to be located in the center of the City near the famous monuments ! Thanks !', '3.8', 34),
(35, 'Everything was fine, except that the room I stayed in was not the one shown in the picture', '2.9', 35),
(36, 'Excellent place to stay in the city. Very private and very clean :)', '4.3', 36),
(37, 'Apartment is very quiet and comfortable, with everything one needs, the location is great. Excellent value for money, highly recommended!', '4.5', 37),
(38, 'Great host and a really cozy place to stay. I will come back again!', '4.7', 38),
(39, 'This was a horrible experience. The place was not as shown. The host messaged me roughly 30 minute before check in and said the current place is not available. It was windy and cold and I had just gotten off my can. I will never forget this experience. While standing out in the wind I tried calling the host who was not available and some other man spoke on his behalf. This too after several attempts of reaching answering machine (again, let me remind you it was in cold windy roadside). ', '1.0', 39),
(40, 'Would only rent if it is on sale', '0.0', 40);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `room`
--

CREATE TABLE `room` (
  `ID` int(11) NOT NULL,
  `Description` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `room`
--

INSERT INTO `room` (`ID`, `Description`) VALUES
(1, 'Bedroom'),
(2, 'Bathroom'),
(3, 'Balcony'),
(4, 'Living Room'),
(5, 'Dining Room'),
(6, 'Kitchen'),
(7, 'Garage');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `rule`
--

CREATE TABLE `rule` (
  `ID` int(11) NOT NULL,
  `Description` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `rule`
--

INSERT INTO `rule` (`ID`, `Description`) VALUES
(1, 'No Smoking'),
(2, 'No Pets'),
(3, 'No Partys'),
(4, 'No Events'),
(5, 'No Kids');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `sight`
--

CREATE TABLE `sight` (
  `ID` int(11) NOT NULL,
  `Name` varchar(128) NOT NULL,
  `LocationID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `sight`
--

INSERT INTO `sight` (`ID`, `Name`, `LocationID`) VALUES
(1, 'Hofburg', 61),
(2, 'Schoenbrunn Palace', 62),
(3, 'Statue of Liberty', 63),
(4, 'Central Park', 64),
(5, 'London Eye', 65),
(6, 'Buckingham Palace', 66),
(7, 'Zocalo', 67),
(8, 'Palacio de Bellas Artes', 68),
(9, 'Imperal Palace', 69),
(10, 'Senso-ji Temple', 70),
(11, 'Colosseum', 71),
(12, 'S. Maria Maggiore', 72),
(13, 'Cristo Redentor', 73),
(14, 'Sugarloaf', 74),
(15, 'Prague Castle', 75),
(16, 'Charles Bridge', 76),
(17, 'Kremlin', 77),
(18, 'Saint Basil\'s Cathedral', 78),
(19, 'Royal Ontario Museum', 79),
(20, 'Eaton Centre', 80);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `state`
--

CREATE TABLE `state` (
  `ID` int(11) NOT NULL,
  `Name` varchar(128) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `state`
--

INSERT INTO `state` (`ID`, `Name`) VALUES
(1, 'Aali an Nil'),
(2, 'Aberconwy and Colwyn'),
(3, 'Abruzzo'),
(4, 'Abu Dhabi'),
(5, 'Acre'),
(6, 'Ad Tamim'),
(7, 'Adamaoua'),
(8, 'Adana'),
(9, 'Adiyaman'),
(10, 'Afghanistan'),
(11, 'Afyon'),
(12, 'AG'),
(13, 'Agri'),
(14, 'Aguascalientes'),
(15, 'Ahal'),
(16, 'AI'),
(17, 'Aichi'),
(18, 'Ajman'),
(19, 'Akershus'),
(20, 'Akita'),
(21, 'Aksaray'),
(22, 'Al Anbar'),
(23, 'Al Basrah'),
(24, 'Al Fujayrah'),
(25, 'al Istiwaiyah'),
(26, 'al Khartum'),
(27, 'Al Muthanna'),
(28, 'Al Qadisiyah'),
(29, 'Alabama'),
(30, 'Alagoas'),
(31, 'Alajuela'),
(32, 'Aland'),
(33, 'Alaska'),
(34, 'Alba'),
(35, 'Albania'),
(36, 'Alberta'),
(37, 'Algarve'),
(38, 'Algeria'),
(39, 'Almaty'),
(40, 'Almaty (munic.)'),
(41, 'Alsace'),
(42, 'Altayskiy kray'),
(43, 'Alvsborg'),
(44, 'Amapa'),
(45, 'Amasya'),
(46, 'Amazonas'),
(47, 'American Samoa'),
(48, 'Amurskaya oblast'),
(49, 'An Najaf'),
(50, 'Anatoliki Makedhonia kai Thraki'),
(51, 'Ancash'),
(52, 'Andalusia'),
(53, 'Andaman and Nicobar Is.'),
(54, 'Andhra Pradesh'),
(55, 'Andijon'),
(56, 'Andorra'),
(57, 'Anglesey'),
(58, 'Anguilla'),
(59, 'Anhui'),
(60, 'Ankara'),
(61, 'Antalya'),
(62, 'Antananarivo'),
(63, 'Antigua and Barbuda'),
(64, 'Antioquia'),
(65, 'Antsiranana'),
(66, 'Antwerp'),
(67, 'Anzoategui'),
(68, 'Aomori'),
(69, 'Apure'),
(70, 'Apurimac'),
(71, 'Aqmola'),
(72, 'Aqtobe'),
(73, 'Aquitaine'),
(74, 'AR'),
(75, 'Arad'),
(76, 'Aragon'),
(77, 'Aragua'),
(78, 'Arauca'),
(79, 'Arbil'),
(80, 'Arequipa'),
(81, 'Arges'),
(82, 'Arizona'),
(83, 'Arkansas'),
(84, 'Arkhangelskaya oblast'),
(85, 'Armenia'),
(86, 'Artvin'),
(87, 'Aruba'),
(88, 'Arunachal Pradesh'),
(89, 'Arusha'),
(90, 'As Sulaymaniyah'),
(91, 'ash Shamaliyah'),
(92, 'Ash Shariqah'),
(93, 'ash Sharqiyah'),
(94, 'Assam'),
(95, 'Astrakhanskaya oblast'),
(96, 'Asturias'),
(97, 'Aswan'),
(98, 'Asyut'),
(99, 'Atlantico'),
(100, 'Atlantida'),
(101, 'Attiki'),
(102, 'Atyrau'),
(103, 'Aust Agder'),
(104, 'Australia Capital Territory'),
(105, 'Auvergne'),
(106, 'Aveiro'),
(107, 'Avon'),
(108, 'Ayacucho'),
(109, 'Aydin'),
(110, 'Ayeyarwady'),
(111, 'Azarbayian e Gharbt'),
(112, 'Azarbayian e Sharqi'),
(113, 'Azerbaijan'),
(114, 'Azores'),
(115, 'Babil'),
(116, 'Bacau'),
(117, 'Bacs Kiskun'),
(118, 'Badakhshoni Kuni'),
(119, 'Baden Wurttemberg'),
(120, 'Baghdad'),
(121, 'Bago'),
(122, 'Bahamas'),
(123, 'Bahia'),
(124, 'Bahr al Ghazal'),
(125, 'Bahrain'),
(126, 'Baja California'),
(127, 'Baja California Sur'),
(128, 'Bakhtaran'),
(129, 'Balearic Islands'),
(130, 'Balikesir'),
(131, 'Balkan'),
(132, 'Bandundu'),
(133, 'Bangladesh'),
(134, 'Baranya'),
(135, 'Barbados'),
(136, 'Barinas'),
(137, 'Bas Zaire'),
(138, 'Basilicata'),
(139, 'Basque Country'),
(140, 'Basse Normandie'),
(141, 'Batman'),
(142, 'Batys Qazaqstan'),
(143, 'Bayburt'),
(144, 'Bayern'),
(145, 'BE'),
(146, 'Bedfordshire'),
(147, 'Beijing (munic.)'),
(148, 'Beja'),
(149, 'Bekes'),
(150, 'Belarus'),
(151, 'Belgorodskaya oblast'),
(152, 'Belize'),
(153, 'Bengo'),
(154, 'Benguela'),
(155, 'Beni Suef'),
(156, 'Benin'),
(157, 'Berkshire'),
(158, 'Berlin'),
(159, 'Bermuda'),
(160, 'Bhutan'),
(161, 'Bialostockie'),
(162, 'Bialskopodlaskie'),
(163, 'Bie'),
(164, 'Bielskie'),
(165, 'Bihar'),
(166, 'Bihor'),
(167, 'Bilecik'),
(168, 'Bingol'),
(169, 'Bistrita Nasaud'),
(170, 'Bitlis'),
(171, 'BL'),
(172, 'Blaenau Gwent'),
(173, 'Blekinge'),
(174, 'Bocas del Toro'),
(175, 'Bolivar'),
(176, 'Bolivia'),
(177, 'Bolu'),
(178, 'Borders'),
(179, 'Borsod Abauj Zemplen'),
(180, 'Bosnia and Herzegovina'),
(181, 'Botosani'),
(182, 'Botswana'),
(183, 'Bourgogne'),
(184, 'Boyaca'),
(185, 'Boyer Ahmad e Kohkiluyeh'),
(186, 'Brabant'),
(187, 'Braga'),
(188, 'Braganca'),
(189, 'Braila'),
(190, 'Brandenburg'),
(191, 'Brasov'),
(192, 'Bremen'),
(193, 'Bretagne'),
(194, 'Bridgend'),
(195, 'British Columbia'),
(196, 'British Virgin Islands'),
(197, 'Brunei'),
(198, 'Bryanskaya oblast'),
(199, 'BS'),
(200, 'Buckinghamshire'),
(201, 'Bucuresti'),
(202, 'Budapest (munic.)'),
(203, 'Buenos Aires'),
(204, 'Bukhoro'),
(205, 'Bulgaria'),
(206, 'Bur Said (munic.)'),
(207, 'Burdur'),
(208, 'Burgenland'),
(209, 'Burkina Faso'),
(210, 'Bursa'),
(211, 'Burundi'),
(212, 'Bushehr'),
(213, 'Buskerud'),
(214, 'Buzau'),
(215, 'Bydgoskie'),
(216, 'Cabinda'),
(217, 'Cabo Delgado'),
(218, 'Caerphilly'),
(219, 'Cajamarca'),
(220, 'Calabria'),
(221, 'Calarasi'),
(222, 'Caldas'),
(223, 'California'),
(224, 'Callao'),
(225, 'Camaguey'),
(226, 'Cambodia'),
(227, 'Cambridgeshire'),
(228, 'Campania'),
(229, 'Campeche'),
(230, 'Canakkale'),
(231, 'Canary Islands'),
(232, 'Cankiri'),
(233, 'Cantabria'),
(234, 'Cape Verde'),
(235, 'Caqueta'),
(236, 'Carabobo'),
(237, 'Caras Severin'),
(238, 'Cardiff'),
(239, 'Carinthia'),
(240, 'Carmarthenshire'),
(241, 'Cartago'),
(242, 'Casanare'),
(243, 'Castelo Branco'),
(244, 'Castile and Leon'),
(245, 'Castile La Mancha'),
(246, 'Catalonia'),
(247, 'Catamarca'),
(248, 'Cauca'),
(249, 'Cayman Islands'),
(250, 'Ceara'),
(251, 'Central'),
(252, 'Central African Republic'),
(1433, 'Central Bohemian'),
(253, 'Centre'),
(254, 'Ceredigion'),
(255, 'Cesar'),
(256, 'Chaco'),
(257, 'Chad'),
(258, 'Chahar Mahal e Bakhtiari'),
(259, 'Champagne Ardenne'),
(260, 'Chandigarh'),
(261, 'Chechen Rep.'),
(262, 'Chelmskie'),
(263, 'Chelyabinskaya oblast'),
(264, 'Cherkaska'),
(265, 'Chernihivska'),
(266, 'Chernivetska'),
(267, 'Cheshire'),
(268, 'Chiapas'),
(269, 'Chiba'),
(270, 'Chihuahua'),
(271, 'Chile'),
(272, 'Chin'),
(273, 'Chiriqui'),
(274, 'Chitinskaya oblast'),
(275, 'Choco'),
(276, 'Choluteca'),
(277, 'Christmas Island'),
(278, 'Chubut'),
(279, 'Chukotsky ao'),
(280, 'Chuvash Republic'),
(281, 'Ciechanowskie'),
(282, 'Ciego de Avila'),
(283, 'Cienfuegos'),
(284, 'Ciudad de la Habana'),
(285, 'Cleveland'),
(286, 'Cluj'),
(287, 'Coahuila'),
(288, 'Coast'),
(289, 'Cocle'),
(290, 'Cocos Islands'),
(291, 'Coimbra'),
(292, 'Cojedes'),
(293, 'Colima'),
(294, 'Colon'),
(295, 'Colorado'),
(296, 'Comarca de San Blas'),
(297, 'Comayagua'),
(298, 'Comoros'),
(299, 'Congo'),
(300, 'Connecticut'),
(301, 'Constanta'),
(302, 'Cook Islands'),
(303, 'Copan'),
(304, 'Copperbelt'),
(305, 'Cordoba'),
(306, 'Cornwall'),
(307, 'Corrientes'),
(308, 'Corse'),
(309, 'Cortes'),
(310, 'Corum'),
(311, 'Cote dIvoire'),
(312, 'Cote/Littoral'),
(313, 'Covasna'),
(314, 'Croatia'),
(315, 'Csongrad'),
(316, 'Cuando Cubango'),
(317, 'Cuanza Norte'),
(318, 'Cuanza Sul'),
(319, 'Cumbria'),
(320, 'Cundinamarca'),
(321, 'Cunene'),
(322, 'Cuzco'),
(323, 'Cyprus'),
(324, 'Czestochowskie'),
(325, 'Dadra and Nagar Haveli'),
(326, 'Dahuk'),
(327, 'Dakar'),
(328, 'Dalarna'),
(329, 'Daman and Diu'),
(330, 'Daressalam'),
(331, 'Darfur'),
(332, 'Darien'),
(333, 'Dashhowuz'),
(334, 'Debrecen (munic.)'),
(335, 'Delaware'),
(336, 'Delhi'),
(337, 'Delta Amacuro'),
(338, 'Denbighshire'),
(339, 'Denizli'),
(340, 'Denmark'),
(341, 'Derbyshire'),
(342, 'Devon'),
(343, 'Dhi Qar'),
(344, 'Dhytiki Ellas'),
(345, 'Dhytiki Makedhonia'),
(346, 'Dimbovita'),
(347, 'Diourbel'),
(348, 'Distr. Columbia'),
(349, 'Distrito Federal'),
(350, 'Diyala'),
(351, 'Diyarbakir'),
(352, 'Djibouti'),
(353, 'Dnipropetrovska'),
(354, 'Dodoma'),
(355, 'Dolj'),
(356, 'Dominica'),
(357, 'Dominican Republic'),
(358, 'Donetska'),
(359, 'Dorset'),
(360, 'Drenthe'),
(361, 'Dubayy'),
(362, 'Dumfries and Galloway'),
(363, 'Dumyat'),
(364, 'Durango'),
(365, 'Durham'),
(366, 'Dushanbe (munic.)'),
(367, 'East Flanders'),
(368, 'East Sussex'),
(369, 'Eastern'),
(370, 'Eastern Cape'),
(371, 'Ecuador'),
(372, 'Edirne'),
(373, 'Ehime'),
(374, 'El Bahr el Ahmar'),
(375, 'El Buhayra'),
(376, 'El Daqahliya'),
(377, 'El Faiyum'),
(378, 'El Gharbiya'),
(379, 'El Giza'),
(380, 'El Iskandariya'),
(381, 'El Minufiya'),
(382, 'El Minya'),
(383, 'El Paraiso'),
(384, 'El Qahira'),
(385, 'El Qalubiya'),
(386, 'El Salvador'),
(387, 'El Suweiz'),
(388, 'El Wadi el Jadid'),
(389, 'Elazig'),
(390, 'Elblaskie'),
(391, 'Emilia Romagna'),
(392, 'Entre Rios'),
(393, 'Equateur'),
(394, 'Equatorial Guinea'),
(395, 'Eritrea'),
(396, 'Erzincan'),
(397, 'Erzurum'),
(398, 'Esfahan'),
(399, 'Eskisehir'),
(400, 'Espirito Santo'),
(401, 'Essex'),
(402, 'Est'),
(403, 'Estonia'),
(404, 'Estremadura'),
(405, 'Ethiopia'),
(406, 'Evora'),
(407, 'Falcon'),
(408, 'Falkland Islands'),
(409, 'Farghona'),
(410, 'Faroe Islands'),
(411, 'Fars'),
(412, 'Fatick'),
(413, 'Fed. Terr. of Kuala Lumpur'),
(414, 'Fed. Terr. of Labuan'),
(415, 'Fejer'),
(416, 'Fianarantsoa'),
(417, 'Fife'),
(418, 'Fiji'),
(419, 'Finnmark'),
(420, 'Flevoland'),
(421, 'Flintshire'),
(422, 'Florida'),
(423, 'Formosa'),
(424, 'FR'),
(425, 'Franche Comte'),
(426, 'Francisco Morazan'),
(427, 'Free State'),
(428, 'French Guiana'),
(429, 'French Polynesia'),
(430, 'Friesland'),
(431, 'Friuli Venezia Giulia'),
(432, 'Fujian'),
(433, 'Fukui'),
(434, 'Fukuoka'),
(435, 'Fukushima'),
(436, 'Gabon'),
(437, 'Galati'),
(438, 'Galicia'),
(439, 'Gambia'),
(440, 'Gansu'),
(441, 'Gauteng'),
(442, 'Gavleborg'),
(443, 'Gaza'),
(444, 'Gaza Strip'),
(445, 'Gaziantep'),
(446, 'Gdanskie'),
(447, 'GE'),
(448, 'Gelderland'),
(449, 'Georgia'),
(450, 'Ghana'),
(451, 'Gibraltar'),
(452, 'Gifu'),
(453, 'Gilan'),
(454, 'Giresun'),
(455, 'Giurgiu'),
(456, 'GL'),
(457, 'Gloucestershire'),
(458, 'Goa'),
(459, 'Goias'),
(460, 'Gorj'),
(461, 'Gorzowskie'),
(462, 'Goteborg och Bohus'),
(463, 'Gotland'),
(464, 'GR'),
(465, 'Gracias a Dios'),
(466, 'Grampian'),
(467, 'Granma'),
(468, 'Greater London'),
(469, 'Greater Manchester'),
(470, 'Greenland'),
(471, 'Grenada'),
(472, 'Groningen'),
(473, 'Guadeloupe'),
(474, 'Guainia'),
(475, 'Guajira, La'),
(476, 'Guam'),
(477, 'Guanacaste'),
(478, 'Guanajuato'),
(479, 'Guangdong'),
(480, 'Guangxi Zhuangzu'),
(481, 'Guantanamo'),
(482, 'Guarda'),
(483, 'Guarico'),
(484, 'Guatemala'),
(485, 'Guaviare'),
(486, 'Guernsey'),
(487, 'Guerrero'),
(488, 'Guinea'),
(489, 'Guinea-Bissau'),
(490, 'Guizhou'),
(491, 'Gujarat'),
(492, 'Gumma'),
(493, 'Gumushane'),
(494, 'Guyana'),
(495, 'Gwynedd'),
(496, 'Gyor (munic.)'),
(497, 'Gyor Sopron'),
(498, 'Haeme'),
(499, 'Haifa'),
(500, 'Hainan'),
(501, 'Hainaut'),
(502, 'Haiti'),
(503, 'Hajdu Bihar'),
(504, 'Hakkari'),
(505, 'Halland'),
(506, 'Hamadan'),
(507, 'Hamburg'),
(508, 'Hampshire'),
(509, 'Harghita'),
(510, 'Haryana'),
(511, 'Hatay'),
(512, 'Haut Zaire'),
(513, 'Haute Normandie'),
(514, 'Hawaii'),
(515, 'Hebei'),
(516, 'Hedmark'),
(517, 'Heilongjiang'),
(518, 'Henan'),
(519, 'Heredia'),
(520, 'Hereford and Worcester'),
(521, 'Herrera'),
(522, 'Hertfordshire'),
(523, 'Hessen'),
(524, 'Heves'),
(525, 'Hidalgo'),
(526, 'Highland'),
(527, 'Himachal Pradesh'),
(528, 'Hiroshima'),
(529, 'Hokkaido'),
(530, 'Holguin'),
(531, 'Holy See'),
(532, 'Hong Kong'),
(533, 'Hordaland'),
(534, 'Hormozgan'),
(535, 'Huambo'),
(536, 'Huancavelica'),
(537, 'Huanuco'),
(538, 'Hubei'),
(539, 'Huila'),
(540, 'Humberside'),
(541, 'Hunan'),
(542, 'Hunedoara'),
(543, 'Hyogo'),
(544, 'Ialomita'),
(545, 'Iasi'),
(546, 'Ibaraki'),
(547, 'Ica'),
(548, 'Icel'),
(549, 'Iceland'),
(550, 'Idaho'),
(551, 'Ilam'),
(552, 'Ile de France'),
(553, 'Illinois'),
(554, 'Indiana'),
(555, 'Indonesia'),
(556, 'Inhambane'),
(557, 'Intibuca'),
(558, 'Ionioi Nisoi'),
(559, 'Iowa'),
(560, 'Ipiros'),
(561, 'Ireland'),
(562, 'Iringa'),
(563, 'Irkutskaya oblast'),
(564, 'Ishikawa'),
(565, 'Isla de la Juventud'),
(566, 'Islas de la Bahia'),
(567, 'Isle of Wight'),
(568, 'Ismailiya'),
(569, 'Isparta'),
(570, 'Istanbul'),
(571, 'Ivano Frankivska'),
(572, 'Ivanovskaya oblast'),
(573, 'Iwate'),
(574, 'Izmir'),
(575, 'Jalisco'),
(576, 'Jamaica'),
(577, 'Jammu and Kashmir'),
(578, 'Jamtland'),
(579, 'Jeleniogorskie'),
(580, 'Jersey'),
(581, 'Jiangsu'),
(582, 'Jiangxi'),
(583, 'Jihocesky'),
(584, 'Jihomoravsky'),
(585, 'Jilin'),
(586, 'Jizzakh'),
(587, 'Johor'),
(588, 'Jonkoping'),
(589, 'Jordan'),
(590, 'JU'),
(591, 'Jujuy'),
(592, 'Junin'),
(593, 'Kabardino Balkar Rep.'),
(594, 'Kachin'),
(595, 'Kafr el Sheikh'),
(596, 'Kagawa'),
(597, 'Kagera'),
(598, 'Kagoshima'),
(599, 'Kaliningradskaya oblast'),
(600, 'Kaliskie'),
(601, 'Kalmar'),
(602, 'Kaluzhskaya oblast'),
(603, 'Kamchatskaya oblast'),
(604, 'Kanagawa'),
(605, 'Kansas'),
(1432, 'Kanto'),
(606, 'Kaolack'),
(607, 'Karachayevo Cherkessk Rep.'),
(608, 'Karaman'),
(609, 'Karamanmaras'),
(610, 'Karbala'),
(611, 'Karnataka'),
(612, 'Kars'),
(613, 'Kasai Occidental'),
(614, 'Kasai Oriental'),
(615, 'Kaskazini Pemba'),
(616, 'Kaskazini Ujunga'),
(617, 'Kastamonu'),
(618, 'Katowickie'),
(619, 'Kayah'),
(620, 'Kayin'),
(621, 'Kayseri'),
(622, 'Kedah'),
(623, 'Kedriki Makedhonia'),
(624, 'Kelantan'),
(625, 'Kemerovskaya oblast'),
(626, 'Kent'),
(627, 'Kentucky'),
(628, 'Kerala'),
(629, 'Kerman'),
(630, 'Khabarovskiy kray'),
(631, 'Kharkivska'),
(632, 'Khatlon'),
(633, 'Khersonska'),
(634, 'Khmelnytska'),
(635, 'Khorasan'),
(636, 'Khorazm'),
(637, 'Khujand'),
(638, 'Khuzestan'),
(639, 'Kieleckie'),
(640, 'Kigoma'),
(641, 'Kilimanjaro'),
(642, 'Kinshasa'),
(643, 'Kiribati'),
(644, 'Kirikkale'),
(645, 'Kirklareli'),
(646, 'Kirovohradska'),
(647, 'Kirovskaya oblast'),
(648, 'Kirsehir'),
(649, 'Kivu'),
(650, 'Kocaeli'),
(651, 'Kochi'),
(652, 'Kokchetau'),
(653, 'Kolda'),
(654, 'Komarom Esztergom'),
(655, 'Koninskie'),
(656, 'Konya'),
(657, 'Kordestan'),
(658, 'Kosovo'),
(659, 'Kostromskaya oblast'),
(660, 'Koszalinskie'),
(661, 'Krakowskie'),
(662, 'Krasnodarsky kray'),
(663, 'Krasnoyarskiy kray'),
(664, 'Kristianstad'),
(665, 'Kriti'),
(666, 'Kronoberg'),
(667, 'Krosnienskie'),
(668, 'Krym'),
(669, 'Kulob'),
(670, 'Kumamoto'),
(671, 'Kuopio'),
(672, 'Kurdufan'),
(673, 'Kurganskaya oblast'),
(674, 'Kurskaya oblast'),
(675, 'Kusini Pemba'),
(676, 'Kusini Ujunga'),
(677, 'Kutahya'),
(678, 'Kuwait'),
(679, 'Kwazulu Natal'),
(680, 'Kymi'),
(681, 'Kyoto'),
(682, 'Kyrgyzstan'),
(683, 'Kyyivska'),
(684, 'La Habana'),
(685, 'La Libertad'),
(686, 'La Pampa'),
(687, 'La Paz'),
(688, 'La Rioja'),
(689, 'Lakshadweep Is.'),
(690, 'Lambayeque'),
(691, 'Lancashire'),
(692, 'Languedoc Roussillon'),
(693, 'Laos'),
(694, 'Lappia'),
(695, 'Lara'),
(696, 'Las Tunas'),
(697, 'Latvia'),
(698, 'Lazio'),
(699, 'Leban'),
(700, 'Lebanon'),
(701, 'Legnickie'),
(702, 'Leicestershire'),
(703, 'Leiria'),
(704, 'Lempira'),
(705, 'Leningradskaya oblast'),
(706, 'Leninsk (munic.)'),
(707, 'Lesotho'),
(708, 'Leszczynskie'),
(709, 'Liaoning'),
(710, 'Liberia'),
(711, 'Libya'),
(712, 'Liechtenstein'),
(713, 'Liege'),
(714, 'Liguria'),
(715, 'Lima'),
(716, 'Limburg'),
(717, 'Limon'),
(718, 'Limousin'),
(719, 'Limpopo'),
(720, 'Lincolnshire'),
(721, 'Lindi'),
(722, 'Lipetskaya oblast'),
(723, 'Lisbon'),
(724, 'Lithuania'),
(725, 'Lodzkie'),
(726, 'Lombardia'),
(727, 'Lomzynskie'),
(728, 'Lorestan'),
(729, 'Loreto'),
(730, 'Lorraine'),
(731, 'Los Santos'),
(732, 'Lothian'),
(733, 'Louga'),
(734, 'Louisiana'),
(735, 'Lower Austria'),
(736, 'LU'),
(737, 'Luanda'),
(738, 'Luapula'),
(739, 'Lubelskie'),
(740, 'Luhanska'),
(741, 'Lunda Norte'),
(742, 'Lunda Sul'),
(743, 'Lusaka'),
(744, 'Luxembourg'),
(745, 'Lvivska'),
(746, 'Macau'),
(747, 'Macedonia'),
(748, 'Madeira'),
(749, 'Madhya Pradesh'),
(750, 'Madre de Dios'),
(751, 'Madrid'),
(752, 'Magadanskaya oblast'),
(753, 'Magdalena'),
(754, 'Magway'),
(755, 'Mahajanga'),
(756, 'Maharashtra'),
(757, 'Maine'),
(758, 'Malanje'),
(759, 'Malatya'),
(760, 'Malawi'),
(761, 'Maldives'),
(762, 'Mali'),
(763, 'Malmohus'),
(764, 'Malta'),
(765, 'Man'),
(766, 'Mandalay'),
(767, 'Mangghystau'),
(768, 'Manica'),
(769, 'Manipur'),
(770, 'Manisa'),
(771, 'Manitoba'),
(772, 'Maputo'),
(773, 'Maputo (munic.)'),
(774, 'Mara'),
(775, 'Maramures'),
(776, 'Maranhao'),
(777, 'Marche'),
(778, 'Mardin'),
(779, 'Markazi'),
(780, 'Marshall Islands'),
(781, 'Martinique'),
(782, 'Mary'),
(783, 'Maryland'),
(784, 'Massachusetts'),
(785, 'Matanzas'),
(786, 'Mato Grosso'),
(787, 'Mato Grosso do Sul'),
(788, 'Matruh'),
(789, 'Mauritania'),
(790, 'Mauritius'),
(791, 'Mayotte'),
(792, 'Maysan'),
(793, 'Mazandaran'),
(794, 'Mbeya'),
(795, 'Mecklenburg Vorpommern'),
(796, 'Meghalaya'),
(797, 'Mehedinti'),
(798, 'Melaka'),
(799, 'Mendoza'),
(800, 'Merida'),
(801, 'Merseyside'),
(802, 'Merthyr Tydfil'),
(803, 'Meta'),
(804, 'Mexico, Estado de'),
(1431, 'Mexiko City'),
(805, 'Michigan'),
(806, 'Michoacan'),
(807, 'Micronesia'),
(808, 'Midi Pyrenees'),
(809, 'Mie'),
(810, 'Mikkeli'),
(811, 'Minas Gerais'),
(812, 'Minnesota'),
(813, 'Miranda'),
(814, 'Misiones'),
(815, 'Miskolc (munic.)'),
(816, 'Mississippi'),
(817, 'Missouri'),
(818, 'Miyagi'),
(819, 'Miyazaki'),
(820, 'Mizoram'),
(821, 'Mjini Magharibi'),
(822, 'Moere og Romsdal'),
(823, 'Moldova'),
(824, 'Molise'),
(825, 'Mon'),
(826, 'Monaco'),
(827, 'Monagas'),
(828, 'Mongolia'),
(829, 'Monmouthshire'),
(830, 'Montana'),
(831, 'Montenegro'),
(832, 'Montserrat'),
(833, 'Moquegua'),
(834, 'Morelos'),
(835, 'Morocco'),
(836, 'Morogoro'),
(837, 'Moskovskaya oblast'),
(838, 'Moskva'),
(839, 'Moxico'),
(840, 'Mpumalanga'),
(841, 'Mtwara'),
(842, 'Mugla'),
(843, 'Murcia'),
(844, 'Mures'),
(845, 'Murmanskaya oblast'),
(846, 'Mus'),
(847, 'Mwanza'),
(848, 'Mykolayivska'),
(849, 'Nagaland'),
(850, 'Nagano'),
(851, 'Nagasaki'),
(852, 'Nairobi'),
(853, 'Namangan'),
(854, 'Namibe'),
(855, 'Namibia'),
(856, 'Nampula'),
(857, 'Namur'),
(858, 'Nara'),
(859, 'Narino'),
(860, 'Nauru'),
(861, 'Navarre'),
(862, 'Nawoiy'),
(863, 'Nayarit'),
(864, 'NE'),
(865, 'Neamt'),
(866, 'Neath and Port Talbot'),
(867, 'Nebraska'),
(868, 'Negeri Sembilan'),
(869, 'Nei Monggol'),
(870, 'Nepal'),
(871, 'Netherlands Antilles'),
(872, 'Neuquen'),
(873, 'Nevada'),
(874, 'Nevsehir'),
(875, 'New Brunswick'),
(876, 'New Caledonia'),
(877, 'New Hampshire'),
(878, 'New Jersey'),
(879, 'New Mexico'),
(880, 'New South Wales'),
(881, 'New York'),
(882, 'New Zealand'),
(883, 'Newfoundland'),
(884, 'Newport'),
(885, 'Niassa'),
(886, 'Nicaragua'),
(887, 'Niedersachsen'),
(888, 'Nigde'),
(889, 'Niger'),
(890, 'Nigeria'),
(891, 'Niigata'),
(892, 'Nil al Asraq'),
(893, 'Ninawa'),
(894, 'Ningxia Huizu'),
(895, 'Niue'),
(896, 'Nizhegorodskaya oblast'),
(897, 'Nograd'),
(898, 'Noord Brabant'),
(899, 'Noord Holland'),
(900, 'Nord'),
(901, 'Nord extreme'),
(902, 'Nord Pas de Calais'),
(903, 'Nord Trondelag'),
(904, 'Nordland'),
(905, 'Nordoueste'),
(906, 'Nordrhein Westfalen'),
(907, 'Norfolk'),
(908, 'Norfolk Island'),
(909, 'Norrbotten'),
(910, 'Norte de Santander'),
(911, 'North'),
(912, 'North Carolina'),
(913, 'North Dakota'),
(914, 'North Eastern'),
(915, 'North Korea'),
(916, 'North West'),
(917, 'North Yorkshire'),
(918, 'Northamptonshire'),
(919, 'Northern'),
(920, 'Northern Cape'),
(921, 'Northern Ireland'),
(922, 'Northern Mariana Islands'),
(923, 'Northern Territory'),
(924, 'Northumberland'),
(925, 'Northwest Territories'),
(926, 'Northwestern'),
(927, 'Notion Aiyaion'),
(928, 'Nottinghamshire'),
(929, 'Nova Scotia'),
(930, 'Novgorodskaya oblast'),
(931, 'Novosibirskaya oblast'),
(932, 'Nowosadeckie'),
(933, 'Nueva Esparta'),
(934, 'Nuevo Leon'),
(935, 'NW'),
(936, 'Nyanza'),
(937, 'Oaxaca'),
(938, 'Ocotepeque'),
(939, 'Odeska'),
(940, 'Oestfold'),
(941, 'Ohio'),
(942, 'Oita'),
(943, 'Okayama'),
(944, 'Okinawa'),
(945, 'Oklahoma'),
(946, 'Olancho'),
(947, 'Olsztynskie'),
(948, 'Olt'),
(949, 'Oman'),
(950, 'Omskaya oblast'),
(951, 'Ongtustik Qazaqstan'),
(952, 'Ontario'),
(953, 'Opolskie'),
(954, 'Oppland'),
(955, 'Ordu'),
(956, 'Orebro'),
(957, 'Oregon'),
(958, 'Orenburgskaya oblast'),
(959, 'Orissa'),
(960, 'Orjolskaya oblast'),
(961, 'Orkneys'),
(962, 'Osaka'),
(963, 'Oslo'),
(964, 'Ostergotland'),
(965, 'Ostroleckie'),
(966, 'Ouest'),
(967, 'Oulu'),
(968, 'Outer Hebrides'),
(969, 'Overijssel'),
(970, 'OW'),
(971, 'Oxfordshire'),
(972, 'Pahang'),
(973, 'Pakistan'),
(974, 'Palau'),
(975, 'Panama'),
(976, 'Papua New Guinea'),
(977, 'Para'),
(978, 'Paraguay'),
(979, 'Paraiba'),
(980, 'Parana'),
(981, 'Pasco'),
(982, 'Pavlodar'),
(983, 'Pays de la Loire'),
(984, 'Pecs (munic.)'),
(985, 'Peloponnisos'),
(986, 'Pembrokeshire'),
(987, 'Pennsylvania'),
(988, 'Penzenskaya oblast'),
(989, 'Perak'),
(990, 'Perlis'),
(991, 'Permskaya oblast'),
(992, 'Pernambuco'),
(993, 'Pest'),
(994, 'Philippines'),
(995, 'Piaui'),
(996, 'Picardie'),
(997, 'Piemonte'),
(998, 'Pilskie'),
(999, 'Pinar del Rio'),
(1000, 'Piotrkowskie'),
(1001, 'Pitcairn Islands'),
(1002, 'Piura'),
(1003, 'Plockie'),
(1004, 'Pohjols-Karjala'),
(1005, 'Poitou Charentes'),
(1006, 'Poltavska'),
(1007, 'Pondicherry'),
(1008, 'Portalegre'),
(1009, 'Porto'),
(1010, 'Portuguesa'),
(1011, 'Powys'),
(1012, 'Poznanskie'),
(1013, 'Praha'),
(1014, 'Prahova'),
(1015, 'Primorsky kray'),
(1016, 'Prince Edward Island'),
(1017, 'Provence Cote dAzur'),
(1018, 'Przemyskie'),
(1019, 'Pskovskaya oblast'),
(1020, 'Puebla'),
(1021, 'Puerto Rico'),
(1022, 'Puglia'),
(1023, 'Pulau Pinang'),
(1024, 'Punjab'),
(1025, 'Puno'),
(1026, 'Puntarenas'),
(1027, 'Putumayo'),
(1028, 'Pwani'),
(1029, 'Qaraghandy'),
(1030, 'Qaraqalpoghiston'),
(1031, 'Qasqadare'),
(1032, 'Qatar'),
(1033, 'Qena'),
(1034, 'Qinghai'),
(1035, 'Qostanay'),
(1036, 'Quebec'),
(1037, 'Queensland'),
(1038, 'Queretaro'),
(1039, 'Quindio'),
(1040, 'Quintana Roo'),
(1041, 'Qyzylorda'),
(1042, 'Radomskie'),
(1043, 'Rajasthan'),
(1044, 'Rakhine'),
(1045, 'Ras al Khaymah'),
(1046, 'Rep. of Adygeya'),
(1047, 'Rep. of Altay'),
(1048, 'Rep. of Bashkortostan'),
(1049, 'Rep. of Buryatiya'),
(1050, 'Rep. of Dagestan'),
(1051, 'Rep. of Ingushetiya'),
(1052, 'Rep. of Kalmykiya'),
(1053, 'Rep. of Karelia'),
(1054, 'Rep. of Khakassiya'),
(1055, 'Rep. of Komi'),
(1056, 'Rep. of Mariy El'),
(1057, 'Rep. of Mordovia'),
(1058, 'Rep. of North Ossetiya'),
(1059, 'Rep. of Sakha'),
(1060, 'Rep. of Tatarstan'),
(1061, 'Rep. of Tyva'),
(1062, 'Reunion'),
(1063, 'Rheinland Pfalz'),
(1064, 'Rhode Island'),
(1065, 'Rhondda Cynon Taff'),
(1066, 'Rhone Alpes'),
(1067, 'Rift Valley'),
(1068, 'Rio de Janeiro'),
(1069, 'Rio Grande do Norte'),
(1070, 'Rio Grande do Sul'),
(1071, 'Rio Negro'),
(1072, 'Rioja'),
(1073, 'Risaralda'),
(1074, 'Rivnenska'),
(1075, 'Rize'),
(1076, 'Rogaland'),
(1077, 'Rondonia'),
(1078, 'Roraima'),
(1079, 'Rostovskaya oblast'),
(1080, 'Rukwa'),
(1434, 'Russian Moskva'),
(1081, 'Ruvuma'),
(1082, 'Rwanda'),
(1083, 'Ryazanskaya oblast'),
(1084, 'Rzeszowskie'),
(1085, 'Saarland'),
(1086, 'Sabah'),
(1087, 'Sachsen'),
(1088, 'Sachsen Anhalt'),
(1089, 'Saga'),
(1090, 'Sagaing'),
(1091, 'Saint Helena'),
(1092, 'Saint Kitts and Nevis'),
(1093, 'Saint Louis'),
(1094, 'Saint Lucia'),
(1095, 'Saint Martin'),
(1096, 'Saint Pierre and Miquelon'),
(1097, 'Saint Vincent and the Grenadines'),
(1098, 'Saitama'),
(1099, 'Sakarya'),
(1100, 'Sakhalinskaya oblast'),
(1101, 'Salah ad Din'),
(1102, 'Salaj'),
(1103, 'Salta'),
(1104, 'Salzburg'),
(1105, 'Samarqand'),
(1106, 'Samarskaya oblast'),
(1107, 'Samoa'),
(1108, 'Samsun'),
(1109, 'San Andres y Providencia'),
(1110, 'San Jose'),
(1111, 'San Juan'),
(1112, 'San Luis'),
(1113, 'San Luis Potosi'),
(1114, 'San Marino'),
(1115, 'San Martin'),
(1116, 'Sancti Spiritus'),
(1117, 'Sankt Peterburg'),
(1118, 'Sanliurfa'),
(1119, 'Santa Barbara'),
(1120, 'Santa Catarina'),
(1121, 'Santa Cruz'),
(1122, 'Santa Fe'),
(1123, 'Santa Fe de Bogota, DC'),
(1124, 'Santander del Sur'),
(1125, 'Santarem'),
(1126, 'Santiago de Cuba'),
(1127, 'Santiago de Estero'),
(1128, 'Sao Paulo'),
(1129, 'Sao Tome and Principe'),
(1130, 'Saratovskaya oblast'),
(1131, 'Sarawak'),
(1132, 'Sardegna'),
(1133, 'Saskatchewan'),
(1134, 'Satu Mare'),
(1135, 'Saudi Arabia'),
(1136, 'Schleswig Holstein'),
(1137, 'Selangor'),
(1138, 'Semey'),
(1139, 'Semnan'),
(1140, 'Serbia'),
(1141, 'Sergipe'),
(1142, 'Setubal'),
(1143, 'Severocesky'),
(1144, 'Severomoravsky'),
(1145, 'Seychelles'),
(1146, 'SG'),
(1147, 'SH'),
(1148, 'Shaanxi'),
(1149, 'Shaba/Katanga'),
(1150, 'Shan'),
(1151, 'Shandong'),
(1152, 'Shanghai (munic.)'),
(1153, 'Shanxi'),
(1154, 'Sharqiya'),
(1155, 'Shetland'),
(1156, 'Shiga'),
(1157, 'Shimane'),
(1158, 'Shinyanga'),
(1159, 'Shizuoka'),
(1160, 'Shropshire'),
(1161, 'Shyghys Qazaqstan'),
(1162, 'Sibiu'),
(1163, 'Sichuan'),
(1164, 'Sicilia'),
(1165, 'Siedleckie'),
(1166, 'Sieradzkie'),
(1167, 'Sierra Leone'),
(1168, 'Siirt'),
(1169, 'Sikkim'),
(1170, 'Sina al Janubiyah'),
(1171, 'Sina ash Shamaliyah'),
(1172, 'Sinaloa'),
(1173, 'Singapore'),
(1174, 'Singida'),
(1175, 'Sinop'),
(1176, 'Sirdare'),
(1177, 'Sirnak'),
(1178, 'Sistan e Baluchestan'),
(1179, 'Sivas'),
(1180, 'Skaraborg'),
(1181, 'Skierniewickie'),
(1182, 'Slovakia'),
(1183, 'Slovenia'),
(1184, 'Slupskie'),
(1185, 'Smolenskaya oblast'),
(1186, 'SO'),
(1187, 'Sodermanland'),
(1188, 'Soer Trondelag'),
(1189, 'Sofala'),
(1190, 'Sogn og Fjordane'),
(1191, 'Sohag'),
(1192, 'Solomon Islands'),
(1193, 'Soltustik Qazaqstan'),
(1194, 'Somalia'),
(1195, 'Somerset'),
(1196, 'Somogy'),
(1197, 'Sonora'),
(1198, 'South'),
(1199, 'South Australia'),
(1200, 'South Carolina'),
(1201, 'South Dakota'),
(1202, 'South Korea'),
(1203, 'South Yorkshire'),
(1204, 'Southern'),
(1205, 'Sri Lanka'),
(1206, 'Staffordshire'),
(1207, 'Stavropolsky kray'),
(1208, 'Sterea Ellas'),
(1209, 'Stockholm'),
(1210, 'Strathclyde'),
(1211, 'Styria'),
(1212, 'Suceava'),
(1213, 'Sucre'),
(1214, 'Sud'),
(1215, 'Sudoueste'),
(1216, 'Suffolk'),
(1217, 'Sumska'),
(1218, 'Suomi'),
(1219, 'Suriname'),
(1220, 'Surkhondare'),
(1221, 'Surrey'),
(1222, 'Suwalskie'),
(1223, 'Svalbard'),
(1224, 'Sverdlovskaya oblast'),
(1225, 'Swansea'),
(1226, 'Swaziland'),
(1227, 'Syria'),
(1228, 'SZ'),
(1229, 'Szabolcs Szatmar'),
(1230, 'Szczecinskie'),
(1231, 'Szeged (munic.)'),
(1232, 'Szolnok'),
(1233, 'Tabasco'),
(1234, 'Tabora'),
(1235, 'Tachira'),
(1236, 'Tacna'),
(1237, 'Taiwan'),
(1238, 'Taldyqorghan'),
(1239, 'Tamaulipas'),
(1240, 'Tambacounda'),
(1241, 'Tambovskaya oblast'),
(1242, 'Tamil Nadu'),
(1243, 'Tanga'),
(1244, 'Tanintharyi'),
(1245, 'Tarnobrzeskie'),
(1246, 'Tarnowskie'),
(1247, 'Tasmania'),
(1248, 'Tayside'),
(1249, 'Tehran'),
(1250, 'Tekirdag'),
(1251, 'Tel Aviv'),
(1252, 'Telemark'),
(1253, 'Teleorman'),
(1254, 'Tennessee'),
(1255, 'Terengganu'),
(1256, 'Ternopilska'),
(1257, 'Tete'),
(1258, 'Texas'),
(1259, 'TG'),
(1260, 'Thailand'),
(1261, 'Thessalia'),
(1262, 'Thies'),
(1263, 'Thuringen'),
(1264, 'TI'),
(1265, 'Tianjin (munic.)'),
(1266, 'Tibet'),
(1267, 'Tierra del Fuego'),
(1268, 'Timis'),
(1269, 'Timor-Leste'),
(1270, 'Tlaxcala'),
(1271, 'Toamasina'),
(1272, 'Tocantins'),
(1273, 'Tochigi'),
(1274, 'Togo'),
(1275, 'Tokat'),
(1276, 'Tokushima'),
(1277, 'Tokyo'),
(1278, 'Toliara'),
(1279, 'Tolima'),
(1280, 'Tolna'),
(1281, 'Tomskaya oblast'),
(1282, 'Tonga'),
(1283, 'Torfaen'),
(1284, 'Torghay'),
(1285, 'Torunskie'),
(1286, 'Toscana'),
(1287, 'Toshkent'),
(1288, 'Tottori'),
(1289, 'Toyama'),
(1290, 'Trabzon'),
(1291, 'Trentino Alto Adige'),
(1292, 'Trinidad and Tobago'),
(1293, 'Tripura'),
(1294, 'Troms'),
(1295, 'Trujillo'),
(1296, 'Tucuman'),
(1297, 'Tulcea'),
(1298, 'Tulskaya oblast'),
(1299, 'Tumbes'),
(1300, 'Tunceli'),
(1301, 'Tunisia'),
(1302, 'Turks and Caicos Islands'),
(1303, 'Turku-Pori'),
(1304, 'Tuvalu'),
(1305, 'Tverskaya oblast'),
(1306, 'Tyne and Wear'),
(1307, 'Tyrol'),
(1308, 'Tyumenskaya oblast'),
(1309, 'Ucayali'),
(1310, 'Udmurt Republic'),
(1311, 'Uganda'),
(1312, 'Uige'),
(1313, 'Ulyanovskaya oblast'),
(1314, 'Umbria'),
(1315, 'Umm al Qaywayn'),
(1316, 'Upper Austria'),
(1317, 'Uppsala'),
(1318, 'UR'),
(1319, 'Uruguay'),
(1320, 'Usak'),
(1321, 'Utah'),
(1322, 'Utrecht'),
(1323, 'Uttar Pradesh'),
(1324, 'Uusimaa'),
(1325, 'Vaasa'),
(1326, 'Vale of Glamorgan'),
(1327, 'Valencia'),
(1328, 'Valle'),
(1329, 'Valle dAosta'),
(1330, 'Valle de Cauca'),
(1331, 'Van'),
(1332, 'Vanuatu'),
(1333, 'Varmland'),
(1334, 'Vas'),
(1335, 'Vaslui'),
(1336, 'Vasterbotten'),
(1337, 'Vasternorrland'),
(1338, 'Vastmanland'),
(1339, 'Vaupes'),
(1340, 'VD'),
(1341, 'Veneto'),
(1342, 'Veracruz'),
(1343, 'Veraguas'),
(1344, 'Vermont'),
(1345, 'Vest Agder'),
(1346, 'Vestfold'),
(1347, 'Veszprem'),
(1348, 'Viana do Castelo'),
(1349, 'Vichada'),
(1350, 'Victoria'),
(1351, 'Vienna'),
(1352, 'Vietnam'),
(1353, 'Vila Real'),
(1354, 'Vilcea'),
(1355, 'Villa Clara'),
(1356, 'Vinnytska'),
(1357, 'Virgin Islands'),
(1358, 'Virginia'),
(1359, 'Viseu'),
(1360, 'Vladimirskaya oblast'),
(1361, 'Volgogradskaya oblast'),
(1362, 'Vologodskaya oblast'),
(1363, 'Volynska'),
(1364, 'Vorarlberg'),
(1365, 'Voreion Aiyaion'),
(1366, 'Voronezhskaya oblast'),
(1367, 'Vrancea'),
(1368, 'VS'),
(1369, 'Vychodocesky'),
(1370, 'Wakayama'),
(1371, 'Walbrzyskie'),
(1372, 'Wallis and Futuna'),
(1373, 'Warszwaskie'),
(1374, 'Warwickshire'),
(1375, 'Washington'),
(1376, 'Wasit'),
(1377, 'West Bank'),
(1378, 'West Bengal'),
(1379, 'West Flanders'),
(1380, 'West Midlands'),
(1381, 'West Sussex'),
(1382, 'West Virginia'),
(1383, 'West Yorkshire'),
(1384, 'Western'),
(1385, 'Western Australia'),
(1386, 'Western Cape'),
(1387, 'Western Sahara'),
(1388, 'Wiltshire'),
(1389, 'Wisconsin'),
(1390, 'Wloclawskie'),
(1391, 'Wrexham'),
(1392, 'Wroclawskie'),
(1393, 'Wyoming'),
(1394, 'Xinjiang Uygur'),
(1395, 'Yamagata'),
(1396, 'Yamaguchi'),
(1397, 'Yamanashi'),
(1398, 'Yangon'),
(1399, 'Yaracuy'),
(1400, 'Yaroslavskaya oblast'),
(1401, 'Yazd'),
(1402, 'Yemen'),
(1403, 'Yevreyskaya avt. oblast'),
(1404, 'Yoro'),
(1405, 'Yozgat'),
(1406, 'Yucatan'),
(1407, 'Yukon Territory'),
(1408, 'Yunnan'),
(1409, 'Zacatecas'),
(1410, 'Zaire'),
(1411, 'Zakarpatska'),
(1412, 'Zala'),
(1413, 'Zambezia'),
(1414, 'Zamojskie'),
(1415, 'Zanjan'),
(1416, 'Zapadocesky'),
(1417, 'Zaporizka'),
(1418, 'Zeeland'),
(1419, 'ZG'),
(1420, 'ZH'),
(1421, 'Zhambyl'),
(1422, 'Zhejiang'),
(1423, 'Zhezkazghan'),
(1424, 'Zhytomyrska'),
(1425, 'Zielonogorskie'),
(1426, 'Ziguinchor'),
(1427, 'Zimbabwe'),
(1428, 'Zonguldak'),
(1429, 'Zuid Holland'),
(1430, 'Zulia');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `transactions`
--

CREATE TABLE `transactions` (
  `ID` int(11) NOT NULL,
  `Amount` decimal(19,2) NOT NULL,
  `Price` decimal(19,2) NOT NULL,
  `Currency` varchar(64) NOT NULL,
  `Received` tinyint(1) NOT NULL DEFAULT 0,
  `Settled` tinyint(1) NOT NULL DEFAULT 0,
  `ExchangeEuroLodging` decimal(20,9) NOT NULL,
  `ExchangeEuroGuest` decimal(20,9) NOT NULL,
  `PaymentOptionID` int(11) NOT NULL,
  `BookingID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `transactions`
--

INSERT INTO `transactions` (`ID`, `Amount`, `Price`, `Currency`, `Received`, `Settled`, `ExchangeEuroLodging`, `ExchangeEuroGuest`, `PaymentOptionID`, `BookingID`) VALUES
(1, '26.25', '25.00', '5', 1, 0, '1.000000000', '0.832984010', 4, 1),
(2, '131.25', '25.00', '5', 1, 0, '1.000000000', '0.038683146', 1, 2),
(3, '88.20', '14.00', '5', 1, 1, '1.000000000', '0.151363080', 4, 3),
(4, '132.30', '14.00', '5', 1, 1, '1.000000000', '0.041789164', 4, 4),
(5, '151.20', '48.00', '1', 0, 0, '0.832984010', '0.664353570', 2, 5),
(6, '252.00', '48.00', '1', 1, 1, '0.832984010', '1.000000000', 1, 6),
(7, '441.00', '70.00', '1', 1, 1, '0.832984010', '0.010859994', 4, 7),
(8, '367.50', '70.00', '1', 1, 1, '0.832984010', '0.007709392', 2, 8),
(9, '632.10', '86.00', '2', 1, 0, '1.157481100', '1.157481100', 2, 9),
(10, '270.90', '86.00', '2', 1, 1, '1.157481100', '0.832984010', 2, 10),
(11, '173.25', '55.00', '2', 1, 0, '1.157481100', '0.832984010', 4, 11),
(12, '231.00', '55.00', '2', 0, 0, '1.157481100', '1.157481100', 1, 12),
(13, '4357.50', '830.00', '7', 0, 0, '0.041789164', '0.007709392', 2, 13),
(14, '2614.50', '830.00', '7', 1, 1, '0.041789164', '0.010859994', 2, 14),
(15, '2898.00', '920.00', '7', 1, 1, '0.041789164', '1.000000000', 3, 15),
(16, '1932.00', '920.00', '7', 1, 1, '0.041789164', '0.664353570', 1, 16),
(17, '161700.00', '14000.00', '3', 1, 0, '0.007709392', '0.041789164', 2, 17),
(18, '58800.00', '14000.00', '3', 0, 0, '0.007709392', '0.151363080', 4, 18),
(19, '64575.00', '12300.00', '3', 0, 0, '0.007709392', '0.038683146', 2, 19),
(20, '12915.00', '12300.00', '3', 1, 1, '0.007709392', '0.832984010', 4, 20),
(21, '411.60', '49.00', '5', 1, 0, '1.000000000', '0.832984010', 2, 21),
(22, '308.70', '49.00', '5', 1, 1, '1.000000000', '0.038683146', 4, 22),
(23, '481.95', '51.00', '5', 1, 1, '1.000000000', '0.151363080', 2, 23),
(24, '160.65', '51.00', '5', 0, 0, '1.000000000', '0.041789164', 2, 24),
(25, '383.25', '73.00', '8', 1, 1, '0.151363080', '0.664353570', 2, 25),
(26, '459.90', '73.00', '8', 1, 1, '0.151363080', '1.000000000', 4, 26),
(27, '351.75', '67.00', '8', 1, 1, '0.151363080', '0.010859994', 1, 27),
(28, '492.45', '67.00', '8', 0, 0, '0.151363080', '0.007709392', 4, 28),
(29, '1449.00', '460.00', '9', 0, 0, '0.038683146', '1.157481100', 4, 29),
(30, '1449.00', '460.00', '9', 0, 0, '0.038683146', '0.832984010', 4, 30),
(31, '3780.00', '900.00', '9', 1, 1, '0.038683146', '0.832984010', 2, 31),
(32, '4725.00', '900.00', '9', 0, 0, '0.038683146', '1.157481100', 2, 32),
(33, '8505.00', '2700.00', '4', 1, 0, '0.010859994', '0.007709392', 3, 33),
(34, '8505.00', '2700.00', '4', 0, 0, '0.010859994', '0.010859994', 3, 34),
(35, '4914.00', '2340.00', '4', 1, 1, '0.010859994', '1.000000000', 4, 35),
(36, '27027.00', '2340.00', '4', 1, 0, '0.010859994', '0.664353570', 3, 36),
(37, '420.00', '100.00', '6', 1, 1, '0.664353570', '0.041789164', 1, 37),
(38, '525.00', '100.00', '6', 1, 1, '0.664353570', '0.151363080', 1, 38),
(39, '173.25', '55.00', '6', 1, 1, '0.664353570', '0.038683146', 2, 39),
(40, '231.00', '55.00', '6', 1, 0, '0.664353570', '0.832984010', 4, 40);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `users`
--

CREATE TABLE `users` (
  `ID` int(11) NOT NULL,
  `Username` varchar(128) NOT NULL,
  `FirstName` varchar(128) NOT NULL,
  `LastName` varchar(128) NOT NULL,
  `Email` varchar(128) NOT NULL,
  `Phone` varchar(20) NOT NULL,
  `About` text DEFAULT NULL,
  `CurrencyID` int(11) NOT NULL,
  `HostID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Daten für Tabelle `users`
--

INSERT INTO `users` (`ID`, `Username`, `FirstName`, `LastName`, `Email`, `Phone`, `About`, `CurrencyID`, `HostID`) VALUES
(1, 'jamsmi23', 'James', 'Smith', 'James.Smith@outlook.eu', '+462080465508', 'We are a small budget lodging for students and traveleres. We offer from daily to monthly rates for a reasonable price.', 5, 1),
(2, 'johwil24', 'John', 'Williams', 'John.Williams@outlook.eu', '+449406701089', '', 1, NULL),
(3, 'robjoh43', 'Robert', 'Johnson', 'Robert.Johnson@gmail.net', '+464381626638', 'I always keep in touch with my guests, you can easily reach out to me via airbnb. I will answer in a few minutes! And if it necessary i can come to the apartment.', 1, 3),
(4, 'micbro13', 'Michael', 'Brown', 'Michael.Brown@yahoo.net', '+416147368059', '', 2, NULL),
(5, 'wiljon28', 'William', 'Jones', 'William.Jones@outlook.net', '+412670827363', 'Hey guys, I work in publishing and books and art are my passionate interest, therefore if you have any questions about current cultural events, please let me know. Best wishes, William', 2, 5),
(6, 'davmil41', 'David', 'Miller', 'David.Miller@yahoo.net', '+498183286863', '', 3, NULL),
(7, 'ricdav30', 'Richard', 'Davis', 'Richard.Davis@gmail.net', '+423567582238', 'I\'m the property manager of Road House Apartments and welcome people from around the globe to enjoy their stay at its finest.', 7, 7),
(8, 'josgar26', 'Joseph', 'Garcia', 'Joseph.Garcia@hotmail.net', '+434958224790', '', 4, NULL),
(9, 'thorod48', 'Thomas', 'Rodriguez', 'Thomas.Rodriguez@hotmail.net', '+459933200528', 'Easy-going human being who loves to interact with others. Smiling is my strength and friendliness is my duty. - 1? per booking goes to building water wells (charity)', 3, 9),
(10, 'chawil27', 'Charles', 'Wilson', 'Charles.Wilson@gmail.eu', '+411777541737', '', 5, NULL),
(11, 'marmar22', 'Mary', 'Martinez', 'Mary.Martinez@hotmail.eu', '+478752305328', 'I like to travel myself and to explore new cities. Hope to give to my guests all what I myself expect when travelling. Will try my best to make your stay as comfortable as possible. See You!', 5, 11),
(12, 'patand16', 'Patricia', 'Anderson', 'Patricia.Anderson@hotmail.net', '+457288421822', '', 6, NULL),
(13, 'jentay18', 'Jennifer', 'Taylor', 'Jennifer.Taylor@yahoo.com', '+437338136318', 'I will be glad to invite you:) I can answer any your questions about city and apartment', 8, 13),
(14, 'linmoo16', 'Linda', 'Moore', 'Linda.Moore@yahoo.eu', '+495215017044', '', 7, NULL),
(15, 'elitho25', 'Elizabeth', 'Thompson', 'Elizabeth.Thompson@gmail.net', '+485546319574', 'Dear guests, I want your stay to be an amazing experience so if there\'s anything you need, feel free to ask.', 9, 15),
(16, 'barlee29', 'Barbara', 'Lee', 'Barbara.Lee@yahoo.net', '+453773648177', '', 8, NULL),
(17, 'sushar33', 'Susan', 'Harris', 'Susan.Harris@gmail.com', '+419624751768', 'I\'m a little bit awkward but I hope I can give u a good hospitality!.... is that the way people say it?', 4, 17),
(18, 'jesrob2', 'Jessica', 'Robinson', 'Jessica.Robinson@hotmail.eu', '+414796861462', '', 9, NULL),
(19, 'sarhal41', 'Sarah', 'Hall', 'Sarah.Hall@outlook.com', '+422352318196', 'Please feel free to text or call if you have any questions or requests. I also speak Russian, French, Italian, Bulgarian, a bit of Spanish and German. I am committed to providing a comfortable stay.', 6, 19),
(20, 'karwal31', 'Karen', 'Walker', 'Karen.Walker@outlook.com', '+426338448897', '', 1, NULL);

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `booking`
--
ALTER TABLE `booking`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `UsersID` (`UsersID`),
  ADD KEY `LodgingID` (`LodgingID`);

--
-- Indizes für die Tabelle `city`
--
ALTER TABLE `city`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `continent`
--
ALTER TABLE `continent`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `country`
--
ALTER TABLE `country`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `currency`
--
ALTER TABLE `currency`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `furnishing`
--
ALTER TABLE `furnishing`
  ADD PRIMARY KEY (`ID`);

--
-- Indizes für die Tabelle `location`
--
ALTER TABLE `location`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `CityID` (`CityID`),
  ADD KEY `StateID` (`StateID`),
  ADD KEY `CountryID` (`CountryID`),
  ADD KEY `ContinentID` (`ContinentID`);

--
-- Indizes für die Tabelle `lodging`
--
ALTER TABLE `lodging`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Description` (`Description`),
  ADD KEY `CurrencyID` (`CurrencyID`),
  ADD KEY `LocationID` (`LocationID`),
  ADD KEY `UsersID` (`UsersID`);

--
-- Indizes für die Tabelle `lodging_furnishing`
--
ALTER TABLE `lodging_furnishing`
  ADD PRIMARY KEY (`LodgingID`,`FurnishingID`),
  ADD KEY `FurnishingID` (`FurnishingID`);

--
-- Indizes für die Tabelle `lodging_policy`
--
ALTER TABLE `lodging_policy`
  ADD PRIMARY KEY (`LodgingID`,`PolicyID`),
  ADD KEY `PolicyID` (`PolicyID`);

--
-- Indizes für die Tabelle `lodging_room`
--
ALTER TABLE `lodging_room`
  ADD PRIMARY KEY (`LodgingID`,`RoomID`),
  ADD KEY `RoomID` (`RoomID`);

--
-- Indizes für die Tabelle `lodging_rule`
--
ALTER TABLE `lodging_rule`
  ADD PRIMARY KEY (`LodgingID`,`RuleID`),
  ADD KEY `RuleID` (`RuleID`);

--
-- Indizes für die Tabelle `paymentoption`
--
ALTER TABLE `paymentoption`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `policy`
--
ALTER TABLE `policy`
  ADD PRIMARY KEY (`ID`);

--
-- Indizes für die Tabelle `publictransport`
--
ALTER TABLE `publictransport`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `LocationID` (`LocationID`);

--
-- Indizes für die Tabelle `review`
--
ALTER TABLE `review`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `BookingID` (`BookingID`);

--
-- Indizes für die Tabelle `room`
--
ALTER TABLE `room`
  ADD PRIMARY KEY (`ID`);

--
-- Indizes für die Tabelle `rule`
--
ALTER TABLE `rule`
  ADD PRIMARY KEY (`ID`);

--
-- Indizes für die Tabelle `sight`
--
ALTER TABLE `sight`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`),
  ADD KEY `LocationID` (`LocationID`);

--
-- Indizes für die Tabelle `state`
--
ALTER TABLE `state`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name` (`Name`);

--
-- Indizes für die Tabelle `transactions`
--
ALTER TABLE `transactions`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `PaymentOptionID` (`PaymentOptionID`),
  ADD KEY `BookingID` (`BookingID`);

--
-- Indizes für die Tabelle `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Username` (`Username`),
  ADD KEY `CurrencyID` (`CurrencyID`),
  ADD KEY `HostID` (`HostID`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `booking`
--
ALTER TABLE `booking`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT für Tabelle `city`
--
ALTER TABLE `city`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3045;

--
-- AUTO_INCREMENT für Tabelle `continent`
--
ALTER TABLE `continent`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT für Tabelle `country`
--
ALTER TABLE `country`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=239;

--
-- AUTO_INCREMENT für Tabelle `currency`
--
ALTER TABLE `currency`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT für Tabelle `furnishing`
--
ALTER TABLE `furnishing`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT für Tabelle `location`
--
ALTER TABLE `location`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=81;

--
-- AUTO_INCREMENT für Tabelle `lodging`
--
ALTER TABLE `lodging`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT für Tabelle `paymentoption`
--
ALTER TABLE `paymentoption`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT für Tabelle `policy`
--
ALTER TABLE `policy`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT für Tabelle `publictransport`
--
ALTER TABLE `publictransport`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT für Tabelle `review`
--
ALTER TABLE `review`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT für Tabelle `room`
--
ALTER TABLE `room`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT für Tabelle `rule`
--
ALTER TABLE `rule`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT für Tabelle `sight`
--
ALTER TABLE `sight`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT für Tabelle `state`
--
ALTER TABLE `state`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1435;

--
-- AUTO_INCREMENT für Tabelle `transactions`
--
ALTER TABLE `transactions`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT für Tabelle `users`
--
ALTER TABLE `users`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- Constraints der exportierten Tabellen
--

--
-- Constraints der Tabelle `booking`
--
ALTER TABLE `booking`
  ADD CONSTRAINT `booking_ibfk_1` FOREIGN KEY (`UsersID`) REFERENCES `users` (`ID`) ON DELETE SET NULL,
  ADD CONSTRAINT `booking_ibfk_2` FOREIGN KEY (`LodgingID`) REFERENCES `lodging` (`ID`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `location`
--
ALTER TABLE `location`
  ADD CONSTRAINT `location_ibfk_1` FOREIGN KEY (`CityID`) REFERENCES `city` (`ID`),
  ADD CONSTRAINT `location_ibfk_2` FOREIGN KEY (`StateID`) REFERENCES `state` (`ID`),
  ADD CONSTRAINT `location_ibfk_3` FOREIGN KEY (`CountryID`) REFERENCES `country` (`ID`),
  ADD CONSTRAINT `location_ibfk_4` FOREIGN KEY (`ContinentID`) REFERENCES `continent` (`ID`);

--
-- Constraints der Tabelle `lodging`
--
ALTER TABLE `lodging`
  ADD CONSTRAINT `lodging_ibfk_1` FOREIGN KEY (`CurrencyID`) REFERENCES `currency` (`ID`),
  ADD CONSTRAINT `lodging_ibfk_2` FOREIGN KEY (`LocationID`) REFERENCES `location` (`ID`),
  ADD CONSTRAINT `lodging_ibfk_3` FOREIGN KEY (`UsersID`) REFERENCES `users` (`ID`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `lodging_furnishing`
--
ALTER TABLE `lodging_furnishing`
  ADD CONSTRAINT `lodging_furnishing_ibfk_1` FOREIGN KEY (`LodgingID`) REFERENCES `lodging` (`ID`) ON DELETE CASCADE,
  ADD CONSTRAINT `lodging_furnishing_ibfk_2` FOREIGN KEY (`FurnishingID`) REFERENCES `furnishing` (`ID`);

--
-- Constraints der Tabelle `lodging_policy`
--
ALTER TABLE `lodging_policy`
  ADD CONSTRAINT `lodging_policy_ibfk_1` FOREIGN KEY (`LodgingID`) REFERENCES `lodging` (`ID`) ON DELETE CASCADE,
  ADD CONSTRAINT `lodging_policy_ibfk_2` FOREIGN KEY (`PolicyID`) REFERENCES `policy` (`ID`);

--
-- Constraints der Tabelle `lodging_room`
--
ALTER TABLE `lodging_room`
  ADD CONSTRAINT `lodging_room_ibfk_1` FOREIGN KEY (`LodgingID`) REFERENCES `lodging` (`ID`) ON DELETE CASCADE,
  ADD CONSTRAINT `lodging_room_ibfk_2` FOREIGN KEY (`RoomID`) REFERENCES `room` (`ID`);

--
-- Constraints der Tabelle `lodging_rule`
--
ALTER TABLE `lodging_rule`
  ADD CONSTRAINT `lodging_rule_ibfk_1` FOREIGN KEY (`LodgingID`) REFERENCES `lodging` (`ID`) ON DELETE CASCADE,
  ADD CONSTRAINT `lodging_rule_ibfk_2` FOREIGN KEY (`RuleID`) REFERENCES `rule` (`ID`);

--
-- Constraints der Tabelle `publictransport`
--
ALTER TABLE `publictransport`
  ADD CONSTRAINT `publictransport_ibfk_1` FOREIGN KEY (`LocationID`) REFERENCES `location` (`ID`);

--
-- Constraints der Tabelle `review`
--
ALTER TABLE `review`
  ADD CONSTRAINT `review_ibfk_1` FOREIGN KEY (`BookingID`) REFERENCES `booking` (`ID`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `sight`
--
ALTER TABLE `sight`
  ADD CONSTRAINT `sight_ibfk_1` FOREIGN KEY (`LocationID`) REFERENCES `location` (`ID`);

--
-- Constraints der Tabelle `transactions`
--
ALTER TABLE `transactions`
  ADD CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`PaymentOptionID`) REFERENCES `paymentoption` (`ID`),
  ADD CONSTRAINT `transactions_ibfk_2` FOREIGN KEY (`BookingID`) REFERENCES `booking` (`ID`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`CurrencyID`) REFERENCES `currency` (`ID`),
  ADD CONSTRAINT `users_ibfk_2` FOREIGN KEY (`HostID`) REFERENCES `users` (`ID`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
