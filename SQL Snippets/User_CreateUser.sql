DELIMITER //

CREATE PROCEDURE User_CreateUser(
    IN username VARCHAR(128),
    IN firstname VARCHAR(128),
    IN lastname VARCHAR(128),
    IN email VARCHAR(128),
    IN phone VARCHAR(20),
    IN currency VARCHAR(64),
    IN about TEXT, 
    OUT message VARCHAR(128)
) 
BEGIN
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
END //
	
	